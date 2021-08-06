// Masterminter uses this to configure which minter the minter controller manages

import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction (publicKey: String, sig: String, addr: Address, method: String, amount: UFix64, toAddr: Address) {
    prepare(oneOfMultiSig: AuthAccount) {
    }

    execute {
        let vaultedAcct = getAccount(addr)

        let pubSigRef = vaultedAcct.getCapability(MultiSigFlowToken.VaultPubSigner)
            .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
            ?? panic("Could not borrow vault pub sig reference")
            
        let amountArg = OnChainMultiSig.PayloadArg(t: Type<UFix64>(), v: amount);
        let toAddrArg = OnChainMultiSig.PayloadArg(t: Type<Address>(), v: toAddr);
        let p = OnChainMultiSig.PayloadDetails(method: method, args: [amountArg, toAddrArg]);
        return pubSigRef.addNewPayload(payload: p, publicKey: publicKey, sig: sig.decodeHex()) 
    }
}
