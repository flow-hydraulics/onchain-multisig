// Masterminter uses this to configure which minter the minter controller manages

import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}

transaction (keyListIndex: Int, sig: [UInt8], addr: Address, method: String, amount: UFix64) {
    prepare(oneOfMultiSig: AuthAccount) {
    }

    execute {
        let vaultedAcct = getAccount(addr)

        let pubSigRef = vaultedAcct.getCapability(MultiSigFlowToken.VaultPubSigner)
            .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
            ?? panic("Could not borrow vault pub sig reference")
            
        let amountArg = OnChainMultiSig.PayloadArg(t: Type<UFix64>(), v: amount);
        // TODO Add to as arg
        let p = OnChainMultiSig.PayloadDetails(method: method, args: [amountArg]);
        return pubSigRef.addNewPayload(payload: p, keyListIndex: keyListIndex, sig: sig) 
    }
}
