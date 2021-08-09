// Masterminter uses this to configure which minter the minter controller manages

import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction (sig: String, txIndex: UInt64, method: String, args: [AnyStruct], publicKey: String, addr: Address ) {
    prepare(oneOfMultiSig: AuthAccount) {
    }

    execute {
        let vaultedAcct = getAccount(addr)

        let pubSigRef = vaultedAcct.getCapability(MultiSigFlowToken.VaultPubSigner)
            .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
            ?? panic("Could not borrow vault pub sig reference")
        
        let p = OnChainMultiSig.PayloadDetails(txIndex: txIndex, method: method, args: args);
        return pubSigRef.addNewPayload(payload: p, publicKey: publicKey, sig: sig.decodeHex()) 
    }
}
