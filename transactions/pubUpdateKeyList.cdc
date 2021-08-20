// This tx attempts to directly modify keyList in a multiSigManager by a public account 

import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction (multiSigVaultAddr: Address) {
    prepare(payer: AuthAccount) {
    }

    execute {
        // Get the account of where the multisig vault is 
        let acct = getAccount(multiSigVaultAddr)

        let vaultRef = acct.getCapability(MultiSigFlowToken.VaultPubSigner)
            .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
            ?? panic("Could not borrow vault pub sig reference")
            
        vaultRef.multiSigManager.configureKeys(pks: ["1234"], kws: [0.2])
    }
}
