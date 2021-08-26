package access

import (
	"testing"

	"github.com/bjartek/go-with-the-flow/gwtf"
	util "github.com/flow-hydraulics/onchain-multisig"
	"github.com/stretchr/testify/assert"
)

func TestOwnerCannotUpdateStore(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	ownerAcct := "vaulted-account"
	vaultAcct := "vaulted-account"

	_, err := MultiSig_PubUpdateStore(g, 11, ownerAcct, vaultAcct)
	// error: cannot assign to `multiSigManager`: field has public access
	//  --> 237d2b40b5f6a90dd9ee3aa5c06af26c30a241eab3c75686cc72c5d198aca78f:8:10
	//   |
	// 8 |         s.multiSigManager <-> store
	//   |           ^^^^^^^^^^^^^^^ consider making it publicly settable with `pub(set)`
	//
	// error: cannot assign to constant member: `multiSigManager`
	//  --> 237d2b40b5f6a90dd9ee3aa5c06af26c30a241eab3c75686cc72c5d198aca78f:8:10
	//   |
	// 8 |         s.multiSigManager <-> store
	//   |           ^^^^^^^^^^^^^^^
	assert.Error(t, err)
}

func TestPubCannotUpdateTxIndex(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	pubAcct := "w-1000"
	vaultAcct := "vaulted-account"

	_, err := MultiSig_PubUpdateTxIndex(g, 11, pubAcct, vaultAcct)
	// error: cannot assign to `txIndex`: field has public access
	//     	            	  --> 1f805903cd707281105ae12e6dc76e889b70a1fda5dd9a13dbbf707a920fe561:17:33
	//     	            	   |
	//     	            	17 |         vaultRef.multiSigManager.txIndex = txIndex
	//     	            	   |                                  ^^^^^^^ consider making it publicly settable with `pub(set)`
	assert.Error(t, err)
}

func TestOwnerCannotUpdateTxIndex(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	ownerAcct := "vaulted-account"
	vaultAcct := "vaulted-account"

	_, err := MultiSig_OwnerUpdateTxIndex(g, 11, ownerAcct, vaultAcct)
	// error: cannot assign to `txIndex`: field has public access
	//     	            	  --> 1f805903cd707281105ae12e6dc76e889b70a1fda5dd9a13dbbf707a920fe561:17:33
	//     	            	   |
	//     	            	17 |         vaultRef.multiSigManager.txIndex = txIndex
	//     	            	   |                                  ^^^^^^^ consider making it publicly settable with `pub(set)`
	assert.Error(t, err)
}

func TestPubCannotUpdateKeyList(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	pubAcct := "w-1000"
	vaultAcct := "vaulted-account"

	initKeys, err := util.GetStoreKeys(g, "vaulted-account")
	assert.NoError(t, err)

	_, err = MultiSig_PubUpdateKeyList(g, pubAcct, vaultAcct)
	// error: cannot access `keyList`: field has private access
	//  --> a0a443291841b0ef697e410b6587d13d010cc39ebba9a085562a03624fe27886:18:8
	//  |
	//18 |         vaultRef.multiSigManager.keyList.insert(key: "1aa4", pka)
	//  |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	assert.Error(t, err)
	postKeys, err := util.GetStoreKeys(g, "vaulted-account")
	assert.NoError(t, err)
	assert.Equal(t, initKeys, postKeys)
}

// Owner must use the `addKeys` function in the Vault
func TestOwnerCannotUpdateKeyListDirectly(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	ownerAcct := "vaulted-account"
	vaultAcct := "vaulted-account"

	initKeys, err := util.GetStoreKeys(g, "vaulted-account")
	assert.NoError(t, err)

	_, err = MultiSig_OwnerUpdateKeyList(g, ownerAcct, vaultAcct)

	//	error: cannot access `keyList`: field has private access
	// --> a317001f16f9907ec9a948bf62b70db9469d10eb7f3d0598de982e8e8f73a60d:8:8
	//  |
	//8 |         s.multiSigManager.keyList.insert(key: "1234", pka)
	//  |         ^^^^^^^^^^^^^^^^^^^^^^^^^
	assert.Error(t, err)

	postKeys, err := util.GetStoreKeys(g, "vaulted-account")
	assert.NoError(t, err)
	assert.Equal(t, initKeys, postKeys)
}
