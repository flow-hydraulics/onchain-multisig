// This tx attempts to directly modify keyList in a multiSigManager by the owner of the resource

import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction (multiSigVaultAddr: Address) {
    prepare(owner: AuthAccount) {
        let s = owner.borrow<&MultiSigFlowToken.Vault>(from: MultiSigFlowToken.VaultStoragePath) ?? panic ("cannot borrow own resource")
        let pka = OnChainMultiSig.PubKeyAttr(sa: 1, w: 0.2)
        s.multiSigManager.configureKeys(pks: ["1234"], kws: [0.2])
    }
}
