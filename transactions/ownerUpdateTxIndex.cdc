import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction (multiSigVaultAddr: Address, txIndex: UInt64) {
    prepare(owner: AuthAccount) {
        let s = owner.borrow<&MultiSigFlowToken.Vault>(from: MultiSigFlowToken.VaultStoragePath) ?? panic ("cannot borrow own resource")
        s.signatureStore!.txIndex = txIndex
    }
}
