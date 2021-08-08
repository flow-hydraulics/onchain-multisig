package keys

import (
	"strconv"
	"testing"

	"github.com/bjartek/go-with-the-flow/gwtf"
	util "github.com/flow-hydraulics/onchain-multisig"
	"github.com/flow-hydraulics/onchain-multisig/vault"
	"github.com/stretchr/testify/assert"
)

func TestAddNewPendingKeyRemoval(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")

	vaultAcct := "vaulted-account"
	payerAcct := "owner"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	events, err := MultiSig_NewRemoveSignerPayload(g, vault.Acct500_1, vault.Acct1000, vaultAcct)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, uint64(1), postTxIndex-initTxIndex)

	uuid, err := util.GetVaultUUID(g, vaultAcct)
	assert.NoError(t, err)

	util.NewExpectedEvent("OnChainMultiSig", "NewPayloadAdded").
		AddField("resourceId", strconv.Itoa(int(uuid))).
		AddField("txIndex", strconv.Itoa(int(postTxIndex))).
		AssertEqual(t, events[0])

	_, err = vault.MultiSig_VaultExecuteTx(g, postTxIndex, payerAcct, vaultAcct)
	assert.NoError(t, err)

	removedPk := g.Accounts[vault.Acct500_1].PrivateKey.PublicKey().String()[2:]
	keys, err := util.GetStoreKeys(g, vaultAcct)
	var removed bool = true
	for _, key := range keys {
		if key == removedPk {
			removed = false
		}
	}
	assert.Equal(t, removed, true)
}

func TestRemovaledKeyCannotAddSig(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")

	vaultAcct := "vaulted-account"
	removedAcct := vault.Acct500_1

	_, err := MultiSig_NewRemoveKeyPayloadSignature(g, removedAcct, 1, removedAcct, vaultAcct)
	assert.Error(t, err)
}

func TestAddNewPendingKeyConfig(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")

	vaultAcct := "vaulted-account"
	payerAcct := "owner"
	newAcct := vault.Acct500_1
	newAcctWeight := "100.00000000"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_NewConfigSignerPayload(g, newAcct, newAcctWeight, vault.Acct1000, vaultAcct)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, uint64(1), postTxIndex-initTxIndex)

	_, err = vault.MultiSig_VaultExecuteTx(g, postTxIndex, payerAcct, vaultAcct)
	assert.NoError(t, err)

	weight, err := util.GetKeyWeight(g, vaultAcct, newAcct)
	assert.Equal(t, newAcctWeight, weight.String())
}
