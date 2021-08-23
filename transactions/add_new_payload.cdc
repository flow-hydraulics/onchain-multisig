// New payload to be added to multiSigManager for a resource 

import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}
import FungibleToken from 0x{{.FungibleToken}}

transaction (sig: String, txIndex: UInt64, method: String, args: [AnyStruct], publicKey: String, addr: Address, withdrawAmount: UFix64 ) {
    let rsc: @FungibleToken.Vault? 
    prepare(oneOfMultiSig: AuthAccount) {
        if withdrawAmount != 0.0 {
            // Get a reference to the signer's stored vault
            let vaultRef = oneOfMultiSig.borrow<&MultiSigFlowToken.Vault>(from: MultiSigFlowToken.VaultStoragePath)
                ?? panic("Could not borrow reference to the owner's Vault!")

            // Withdraw tokens from the signer's stored vault
            self.rsc <-vaultRef.withdraw(amount: withdrawAmount) as! @FungibleToken.Vault
        } else {
            self.rsc <- nil
        }
    }

    execute {
        let vaultedAcct = getAccount(addr)

        let pubSigRef = vaultedAcct.getCapability(MultiSigFlowToken.VaultPubSigner)
            .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
            ?? panic("Could not borrow vault pub sig reference")
        
        let p <- OnChainMultiSig.createPayload(txIndex: txIndex, method: method, args: args, rsc: <- self.rsc);
        return pubSigRef.addNewPayload(payload: <-p, publicKey: publicKey, sig: sig.decodeHex()) 
    }
}
