package keys

import (
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
	removedPk := g.Accounts[vault.Acct500_1].PrivateKey.PublicKey().String()[2:]

	hasKey, err := ContainsKey(g, vaultAcct, removedPk)
	assert.NoError(t, err)
	assert.Equal(t, hasKey, true)

	_, err = MultiSig_NewRemoveSignerPayload(g, vault.Acct500_1, vault.Acct1000, vaultAcct)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = vault.MultiSig_VaultExecuteTx(g, postTxIndex, payerAcct, vaultAcct)
	assert.NoError(t, err)

	hasKey, err = ContainsKey(g, vaultAcct, removedPk)
	assert.NoError(t, err)
	assert.Equal(t, hasKey, false)
}

func TestRemovedKeyCannotAddSig(t *testing.T) {
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

	_, err := MultiSig_NewConfigSignerPayload(g, newAcct, newAcctWeight, vault.Acct1000, vaultAcct)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = vault.MultiSig_VaultExecuteTx(g, postTxIndex, payerAcct, vaultAcct)
	assert.NoError(t, err)

	weight, err := util.GetKeyWeight(g, vaultAcct, newAcct)
	assert.NoError(t, err)
	assert.Equal(t, newAcctWeight, weight.String())
}
