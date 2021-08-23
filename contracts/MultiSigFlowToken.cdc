import FungibleToken from 0x{{.FungibleToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

pub contract MultiSigFlowToken: FungibleToken {

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

    // Total supply of Flow tokens in existence
    pub var totalSupply: UFix64

    // Vault
    //
    pub resource Vault: 
        FungibleToken.Provider, 
        FungibleToken.Receiver, 
        FungibleToken.Balance, 
        OnChainMultiSig.PublicSigner, 
        OnChainMultiSig.KeyManager {

        // holds the balance of a users tokens
        pub var balance: UFix64

        // Resource to keep track of partial sigatures and payloads, required for onchain multisig features.
        // Limited to `access(self)` to avoid exposing all functions in `SignatureManager` interface to account owner(s)
        access(self) let multiSigManager: @OnChainMultiSig.Manager;


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
        
        // 
        // Below are the interfaces are required for any resources wanting to use OnChainMultiSig
        // 

        /// To submit a new paylaod, i.e. starting a new tx requiring, potentially requiring more signatures
        pub fun addNewPayload(payload: @OnChainMultiSig.PayloadDetails, publicKey: String, sig: [UInt8]) {
            self.multiSigManager.addNewPayload(resourceId: self.uuid, payload: <-payload, publicKey: publicKey, sig: sig);
        }

        /// To submit a new signature for a pre-exising payload, i.e. adding another signature
        pub fun addPayloadSignature (txIndex: UInt64, publicKey: String, sig: [UInt8]) {
            self.multiSigManager.addPayloadSignature(resourceId: self.uuid, txIndex: txIndex, publicKey: publicKey, sig: sig);
       }
        /// To execute the multisig transaction iff conditions are met
        /// `configureKey` and `removeKey` functions can be used for all resources if see fit
        /// other methods must be implemented to suit the particular resource
        pub fun executeTx(txIndex: UInt64): @AnyResource? {
            let p <- self.multiSigManager.readyForExecution(txIndex: txIndex) ?? panic ("no transactable payload at given txIndex")
            switch p.method {
                case "configureKey":
                    let pubKey = p.getArg(i: 0)! as? String ?? panic ("cannot downcast public key");
                    let weight = p.getArg(i: 1)! as? UFix64 ?? panic ("cannot downcast weight");
                    destroy(p)
                    self.multiSigManager.configureKeys(pks: [pubKey], kws: [weight])
                case "removeKey":
                    let pubKey = p.getArg(i: 0)! as? String ?? panic ("cannot downcast public key");
                    destroy(p)
                    self.multiSigManager.removeKeys(pks: [pubKey])
                case "removePayload":
                    let txIndex = p.getArg(i: 0)! as? UInt64 ?? panic ("cannot downcast txIndex");
                    let payloadToRemove <- self.multiSigManager.removePayload(txIndex: txIndex)
                    // creating a `temp` resource to replace the existing `@[AnyResource]`
                    // https://docs.onflow.org/cadence/language/composite-types/#resources-in-arrays-and-dictionaries
                    var temp: @AnyResource? <- nil 
                    payloadToRemove.rsc <-> temp
                    destroy(p)
                    destroy(payloadToRemove)
                    return <- temp 
                case "withdraw":
                    let amount = p.getArg(i: 0)! as? UFix64 ?? panic ("cannot downcast amount");
                    destroy(p)
                    return <- self.withdraw(amount: amount);
                case "deposit":
                    var temp: @AnyResource? <- nil 
                    p.rsc <-> temp
                    destroy(p)
                    let vault <- temp! as! @FungibleToken.Vault
                    self.deposit(from: <- vault );
                case "transfer":
                    let amount = p.getArg(i: 0)! as? UFix64 ?? panic ("cannot downcast amount");
                    let to = p.getArg(i: 1)! as? Address ?? panic ("cannot downcast address");
                    let toAcct = getAccount(to);
                    let receiver = toAcct.getCapability(MultiSigFlowToken.VaultReceiverPubPath)!
                        .borrow<&{FungibleToken.Receiver}>()
                        ?? panic("Unable to borrow receiver reference for recipient")

                    let v <- self.withdraw(amount: amount);
                    destroy(p)
                    receiver.deposit(from: <- v)
            }
            return nil;
        }

        pub fun UUID(): UInt64 {
            return self.uuid;
        }; 

        pub fun getTxIndex(): UInt64 {
            return self.multiSigManager.txIndex
        }

        pub fun getSignerKeys(): [String] {
            return self.multiSigManager.getSignerKeys()
        }
        pub fun getSignerKeyAttr(publicKey: String): OnChainMultiSig.PubKeyAttr? {
            return self.multiSigManager.getSignerKeyAttr(publicKey: publicKey)
        }

        //
        // --- end of `OnChainMultiSig.PublicSigner` interfaces
        //

        //
        // Optional Priv Capbilities for owner of the vault to add / remove keys `OnChainMultiSig.KeyManager`
        // 
        // These follows the usual account authorization logic
        // i.e. if it is an account with multiple keys, then the total weight of the signatures must be > 1000
        pub fun addKeys( multiSigPubKeys: [String], multiSigKeyWeights: [UFix64]) {
            self.multiSigManager.configureKeys(pks: multiSigPubKeys, kws: multiSigKeyWeights)
        }

        pub fun removeKeys( multiSigPubKeys: [String]) {
            self.multiSigManager.removeKeys(pks: multiSigPubKeys)
        }

        destroy() {
            MultiSigFlowToken.totalSupply = MultiSigFlowToken.totalSupply - self.balance
            destroy self.multiSigManager
        }

        // initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance;
            self.multiSigManager <-  OnChainMultiSig.createMultiSigManager(publicKeys: [], pubKeyAttrs: [])
        }
        
    }

    pub resource Administrator {
    }

    pub fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0.0)
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
