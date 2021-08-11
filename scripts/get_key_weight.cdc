// This script gets the weight of a stored public key in a multiSigManager for a resource 

import FungibleToken from 0x{{.FungibleToken}}
import OnChainMultiSig from 0x{{.OnChainMultiSig}}
import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}

pub fun main(account: Address, key: String): UFix64 {
    let acct = getAccount(account)
    let vaultRef = acct.getCapability(MultiSigFlowToken.VaultPubSigner)
        .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
        ?? panic("Could not borrow Pub Signer reference to the Vault")

    let attr = vaultRef.getSignerKeyAttr(publicKey: key)!
    return attr.weight
}
