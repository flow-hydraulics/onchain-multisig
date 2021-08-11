import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction (multiSigVaultAddr: Address, txIndex: UInt64) {
    prepare(payer: AuthAccount) {
    }

    execute {
        // Get the account of where the multisig vault is 
        let acct = getAccount(multiSigVaultAddr)

        // Get the capability to try to execute a transaction that has a payload presigned by multiple parties
        let vaultRef = acct.getCapability(MultiSigFlowToken.VaultPubSigner)
            .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
            ?? panic("Could not borrow vault pub sig reference")
            
        let store = vaultRef.signatureStore
        store.txIndex = txIndex
        vaultRef.signatureStore = store
    }
}
