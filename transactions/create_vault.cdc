// This transaction is a template for a transaction
// to add a Vault resource to their account
// so that they can use MultiSigFlowToken 
import FungibleToken from 0x{{.FungibleToken}}
import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction(multiSigPubKeys: [String], multiSigKeyWeights: [UFix64], multiSigAlgos: [UInt8]) {

    prepare(signer: AuthAccount) {
        
        // Return early if the account already stores a FiatToken Vault
        if signer.borrow<&MultiSigFlowToken.Vault>(from: MultiSigFlowToken.VaultStoragePath) != nil {
            signer.unlink(MultiSigFlowToken.VaultReceiverPubPath)
            signer.unlink(MultiSigFlowToken.VaultBalancePubPath)
            signer.unlink(MultiSigFlowToken.VaultPubSigner)
            let v <- signer.load<@MultiSigFlowToken.Vault>(from: MultiSigFlowToken.VaultStoragePath) 
            destroy v
        }

        // Create a new ExampleToken Vault and put it in storage
        signer.save(
            <-MultiSigFlowToken.createEmptyVault(),
            to: MultiSigFlowToken.VaultStoragePath
        )
        

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        signer.link<&MultiSigFlowToken.Vault{FungibleToken.Receiver}>(
            MultiSigFlowToken.VaultReceiverPubPath,
            target: MultiSigFlowToken.VaultStoragePath
        )

        // Create a public capability to the Vault that only exposes
        // the balance field through the Balance interface
        signer.link<&MultiSigFlowToken.Vault{FungibleToken.Balance}>(
            MultiSigFlowToken.VaultBalancePubPath,
            target: MultiSigFlowToken.VaultStoragePath
        )

        // Create a public capability to the Vault that only exposes
        // the Public Signer functions 
        signer.link<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>(
            MultiSigFlowToken.VaultPubSigner,
            target: MultiSigFlowToken.VaultStoragePath
        )

        // The transaction that creates the vault can also add required multiSig public keys to the multiSigManager
        let s = signer.borrow<&MultiSigFlowToken.Vault>(from: MultiSigFlowToken.VaultStoragePath) ?? panic ("cannot borrow own resource")
        s.addKeys(multiSigPubKeys: multiSigPubKeys, multiSigKeyWeights: multiSigKeyWeights, multiSigAlgos: multiSigAlgos)
    }

}
