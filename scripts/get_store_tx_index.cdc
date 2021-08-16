// This script gets the current TxIndex for payloads stored in multiSigManager in a resource 
// The new payload must be this value + 1

import OnChainMultiSig from 0x{{.OnChainMultiSig}}
import MultiSigFlowToken from 0x{{.MultiSigFlowToken}}

pub fun main(account: Address): UInt64{
    let acct = getAccount(account)
    let vaultRef = acct.getCapability(MultiSigFlowToken.VaultPubSigner)
        .borrow<&MultiSigFlowToken.Vault{OnChainMultiSig.PublicSigner}>()
        ?? panic("Could not borrow Pub Signer reference to the Vault")

    return vaultRef.getTxIndex()
}
