import FungibleToken from 0x{{.FungibleToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

pub contract MultiSigFlowToken: FungibleToken {

    // Total supply of Flow tokens in existence
    pub var totalSupply: UFix64

    // Event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    // Event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    // Event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    // Vault paths
    pub let VaultStoragePath: StoragePath;
    pub let VaultBalancePubPath: PublicPath;
    pub let VaultReceiverPubPath: PublicPath;
    pub let VaultPubSigner: PublicPath;

    // Vault
    //
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance, OnChainMultiSig.PublicSigner {

        // holds the balance of a users tokens
        pub var balance: UFix64

        // initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance;
            self.signatureStore = OnChainMultiSig.SignatureStore(initialSigner: []);
        }
        
        pub fun addKeys( multiSigPubKeys: [String], multiSigKeyWeights: [UFix64]) {
            // Create keylistElements in the case this is for multisig for the owner account
            // Default signing algo ECDSA_P256 = 1
            let signers: [OnChainMultiSig.KeyListElement] = [];
            let len = multiSigPubKeys.length;
            var i = 0;
            while i < len {
                let ke = OnChainMultiSig.KeyListElement(pk: multiSigPubKeys[i], sa: 1, w: multiSigKeyWeights[i])
                signers.append(ke);
                i = i + 1;
            }
            self.signatureStore = OnChainMultiSig.SignatureStore(initialSigners: signers)
        }

        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @MultiSigFlowToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        // PublicSigner interface requirements 
        // 1. signatureStore: Stores the payloads, transactions pending to be signed and signature
        // 2. addNewPayload: add new transaction payload to the signature store waiting for others to sign
        // 3. addPayloadSignature: add signature to store for existing paylaods by payload index
        // 4. executeTx: attempt to execute the transaction at a given index after required signatures have been added
        // 5. UUID: gets the uuid of this resource 
        // Interfaces 1-3 uses `OnChainMultiSig.Manager` struct for code implementation
        // Interface 4 needs to be implemented specifically for each resource

        /// struct to keep track of partial sigatures
        pub var signatureStore: OnChainMultiSig.SignatureStore;
        
        /// To submit a new paylaod, i.e. starting a new tx requiring more signatures
        pub fun addNewPayload(payload: OnChainMultiSig.PayloadDetails, keyListIndex: Int, sig: [UInt8]) {
            let manager = OnChainMultiSig.Manager(sigStore: self.signatureStore);
            let newSignatureStore = manager.addNewPayload(resourceId: self.uuid, payload: payload, keyListIndex: keyListIndex, sig: sig);
            log("====================")
            log(self.signatureStore)
            log("====================")
            log(newSignatureStore)
            log("====================")
            self.signatureStore = newSignatureStore
        }

        /// To submit a new signature for a pre-exising payload, i.e. adding another signature
        pub fun addPayloadSignature (txIndex: UInt64, keyListIndex: Int, sig: [UInt8]) {
            let manager = OnChainMultiSig.Manager(sigStore: self.signatureStore);
            let newSignatureStore = manager.addPayloadSignature(resourceId: self.uuid, txIndex: txIndex, keyListIndex: keyListIndex, sig: sig);
            self.signatureStore = newSignatureStore
       }
        /// To execute the multisig transaction iff conditions are met
        pub fun executeTx(txIndex: UInt64): @AnyResource? {
            let manager = OnChainMultiSig.Manager(sigStore: self.signatureStore);
            let p = manager.readyForExecution(txIndex: txIndex) ?? panic ("TX not ready for execution")
            switch p.method {
                case "withdraw":
                    let m = p.args[0].value as? UFix64 ?? panic ("cannot downcast amount");
                    return <- self.withdraw(amount: m);
            }
            return nil;
        }

        pub fun UUID(): UInt64 {
            return self.uuid;
        }; 

        destroy() {
            MultiSigFlowToken.totalSupply = MultiSigFlowToken.totalSupply - self.balance
        }
    }

    pub fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0.0)
    }

    pub resource Administrator {
    }


    init(adminAccount: AuthAccount) {
        self.totalSupply = 100000.0

        self.VaultStoragePath = /storage/vault
        self.VaultBalancePubPath = /public/vaultBalance
        self.VaultReceiverPubPath = /public/vaultReceive
        self.VaultPubSigner = /public/vaultMultiSigner

        // Create the Vault with the total supply of tokens and save it in storage
        //
        let vault <- create Vault(balance: self.totalSupply)
        adminAccount.save(<-vault, to: self.VaultStoragePath)

        // Create a public capability to the stored Vault that only exposes
        // the `deposit` method through the `Receiver` interface
        //
        adminAccount.link<&MultiSigFlowToken.Vault{FungibleToken.Receiver}>(
            self.VaultReceiverPubPath,
            target: self.VaultStoragePath 
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field through the `Balance` interface
        //
        adminAccount.link<&MultiSigFlowToken.Vault{FungibleToken.Balance}>(
            self.VaultBalancePubPath,
            target: self.VaultStoragePath 
        )

        let admin <- create Administrator()
        adminAccount.save(<-admin, to: /storage/flowTokenAdmin)

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
