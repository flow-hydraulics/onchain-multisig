// Attempt to execute a transaction with signatures for a txIndex stored in a multiSigManager for a resource 


import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}
import FungibleToken from 0x{{.FungibleToken}}

transaction (multiSigVaultAddr: Address, txIndex: UInt64) {
    let recv: &{FungibleToken.Receiver}
    prepare(payer: AuthAccount) {
        // Get a reference to the signer's stored vault
        self.recv = payer.getCapability(MultiSigFlowToken.VaultReceiverPubPath)!
            .borrow<&{FungibleToken.Receiver}>()
            ?? panic("Unable to borrow receiver reference for recipient")

    }

    execute {
        // Get the account of where the multisig vault is 
        let acct = getAccount(multiSigVaultAddr)

        // Get the capability to try to execute a transaction that has a payload presigned by multiple parties
        let pubSigRef = acct.getCapability(MultiSigFlowToken.VaultPubSigner)
            .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
            ?? panic("Could not borrow vault pub sig reference")
            
        let r <- pubSigRef.executeTx(txIndex: txIndex)
        if r != nil {
            // Withdraw tokens from the signer's stored vault
            let vault <- r! as! @FungibleToken.Vault
            self.recv.deposit(from: <- vault)
        } else {
            destroy(r)
        }
    }
}
