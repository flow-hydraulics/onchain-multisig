// Masterminter uses this to configure which minter the minter controller manages

import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction (publicKey: String, sig: String, addr: Address, method: String, pubKeyToConfig: String, weight: UFix64) {
    prepare(oneOfMultiSig: AuthAccount) {
    }

    execute {
        let vaultedAcct = getAccount(addr)

        let pubSigRef = vaultedAcct.getCapability(MultiSigFlowToken.VaultPubSigner)
            .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
            ?? panic("Could not borrow vault pub sig reference")
            
        let pk = OnChainMultiSig.PayloadArg(t: Type<String>(), v: pubKeyToConfig);
        let w = OnChainMultiSig.PayloadArg(t: Type<UFix64>(), v: weight);
        let p = OnChainMultiSig.PayloadDetails(method: method, args: [pk, w]);
        return pubSigRef.addNewPayload(payload: p, publicKey: publicKey, sig: sig.decodeHex()) 
    }
}
