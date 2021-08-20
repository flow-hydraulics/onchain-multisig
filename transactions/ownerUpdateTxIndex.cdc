// This tx attempts to update the multiSigManager.txIndex resource directly by the owner of the resource 

import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction (multiSigVaultAddr: Address, txIndex: UInt64) {
    prepare(owner: AuthAccount) {
        let s = owner.borrow<&MultiSigFlowToken.Vault>(from: MultiSigFlowToken.VaultStoragePath) ?? panic ("cannot borrow own resource")
        s.multiSigManager.txIndex = txIndex
    }
}
