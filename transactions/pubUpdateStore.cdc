// This tx attempts to update the multiSigManager resource directly by a public account

import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction (multiSigVaultAddr: Address, txIndex: UInt64) {
    prepare(payer: AuthAccount) {
    }

    execute {
        // Get the account of where the multisig vault is 
        let acct = getAccount(multiSigVaultAddr)

        let vaultRef = acct.getCapability(MultiSigFlowToken.VaultPubSigner)
            .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
            ?? panic("Could not borrow vault pub sig reference")
            
        let store <- OnChainMultiSig.createMultiSigManager(publicKeys: [], pubKeyAttrs: [])
        vaultRef.multiSigManager <-> store
        destroy store
    }
}
