// Masterminter uses this to configure which minter the minter controller manages

import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction (publicKey: String, sig: String, addr: Address, method: String, pubKeyToRemove: String) {
    prepare(oneOfMultiSig: AuthAccount) {
    }

    execute {
        let vaultedAcct = getAccount(addr)

        let pubSigRef = vaultedAcct.getCapability(MultiSigFlowToken.VaultPubSigner)
            .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
            ?? panic("Could not borrow vault pub sig reference")
            
        let pk = OnChainMultiSig.PayloadArg(t: Type<String>(), v: pubKeyToRemove);
        let p = OnChainMultiSig.PayloadDetails(method: method, args: [pk]);
        return pubSigRef.addNewPayload(payload: p, publicKey: publicKey, sig: sig.decodeHex()) 
    }
}
