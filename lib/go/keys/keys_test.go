package keys

import (
	"testing"

	"github.com/bjartek/go-with-the-flow/gwtf"
	util "github.com/flow-hydraulics/onchain-multisig"
	"github.com/flow-hydraulics/onchain-multisig/vault"
	"github.com/stretchr/testify/assert"
)

func TestAddAndExecuteKeyRemoval(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")

	vaultAcct := "vaulted-account"
	payerAcct := "owner"
	removedPk := g.Accounts[vault.Acct500_1].PrivateKey.PublicKey().String()[2:]

	hasKey, err := ContainsKey(g, vaultAcct, removedPk)
	assert.NoError(t, err)
	assert.Equal(t, hasKey, true)

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_RemoveKey(g, vault.Acct500_1, initTxIndex+uint64(1), vault.Acct1000, vaultAcct, true)
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

	txIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	// Add a new payload to test new signature cannot be added by removed account
	_, err = MultiSig_RemoveKey(g, vault.Acct500_1, txIndex+uint64(1), vault.Acct1000, vaultAcct, true)
	assert.NoError(t, err)

	_, err = MultiSig_RemoveKey(g, removedAcct, txIndex+uint64(1), removedAcct, vaultAcct, false)
	assert.Error(t, err)
}

func TestAddAndExecuteKeyConfig(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")

	vaultAcct := "vaulted-account"
	payerAcct := "owner"
	newAcct := vault.Acct500_2
	newAcctWeight := "100.00000000"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_ConfigKey(g, newAcct, newAcctWeight, initTxIndex+uint64(1), vault.Acct1000, vaultAcct, true)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = vault.MultiSig_VaultExecuteTx(g, postTxIndex, payerAcct, vaultAcct)
	assert.NoError(t, err)

	weight, err := util.GetKeyWeight(g, vaultAcct, newAcct)
	assert.NoError(t, err)
	assert.Equal(t, newAcctWeight, weight.String())
}

func TestAddAndExecuteNewKeyConfig(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")

	vaultAcct := "vaulted-account"
	payerAcct := "owner"
	newAcct := "non-registered-account"
	newAcctWeight := "150.00000000"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_ConfigKey(g, newAcct, newAcctWeight, initTxIndex+uint64(1), vault.Acct1000, vaultAcct, true)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = vault.MultiSig_VaultExecuteTx(g, postTxIndex, payerAcct, vaultAcct)
	assert.NoError(t, err)

	weight, err := util.GetKeyWeight(g, vaultAcct, newAcct)
	assert.NoError(t, err)
	assert.Equal(t, newAcctWeight, weight.String())
}
