package vault

import (
	"fmt"
	"strconv"
	"testing"

	"github.com/bjartek/go-with-the-flow/gwtf"
	util "github.com/flow-hydraulics/onchain-multisig"
	"github.com/stretchr/testify/assert"
)

func TestAddVaultToAccount(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")

	_, err := AddVaultToAccount(g, "vaulted-account")
	assert.NoError(t, err)

	balance, err := util.GetBalance(g, "vaulted-account")
	assert.NoError(t, err)
	assert.Equal(t, balance.String(), "0.00000000")

	keys, err := util.GetStoreKeys(g, "vaulted-account")
	assert.NoError(t, err)
	assert.Len(t, keys, 5)

	txIndex, err := util.GetTxIndex(g, "vaulted-account")
	assert.NoError(t, err)
	assert.Equal(t, txIndex, uint64(0))

	transferAmount := "100.00000000"
	_, err = AccountSignerTransferTokens(g, transferAmount, "owner", "vaulted-account")
	assert.NoError(t, err)

	balanceA, err := util.GetBalance(g, "vaulted-account")
	assert.NoError(t, err)
	assert.Equal(t, transferAmount, balanceA.String())
}

func TestAddNewPendingTransferPayloadWithFullMultiSigAccount(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	transferAmount := "15.5"
	transferTo := "owner"

	vaultAcct := "vaulted-account"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	events, err := MultiSig_NewPendingTransferPayload(g, transferAmount, transferTo, Acct1000, vaultAcct)
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

	fmt.Println("postTxindex: ", postTxIndex)
}

func TestAddNewPendingTransferPayloadUnknowAcct(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	transferAmount := "15.5000000"
	vaultAcct := "vaulted-account"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_NewPendingTransferPayload(g, transferAmount, "owner", "non-registered-account", vaultAcct)
	assert.Error(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, uint64(0), postTxIndex-initTxIndex)
}

func TestExecutePendingTransnferFromFullAcct(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	transferAmount := "15.50000000"
	payerAcct := "owner"
	vaultAcct := "vaulted-account"
	txIndex := uint64(1)

	initFromBalance, err := util.GetBalance(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_VaultExecuteTx(g, txIndex, payerAcct, vaultAcct)
	assert.NoError(t, err)

	postFromBalance, err := util.GetBalance(g, vaultAcct)
	assert.NoError(t, err)

	assert.Equal(t, transferAmount, (initFromBalance - postFromBalance).String())
}

func TestExecutePayloadWithMultipleSig(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	transferAmount := "15.50000000"
	transferTo := "owner"
	payerAcct := "owner"

	//
	// First add a payload; total authorised weight is 500
	//
	vaultAcct := "vaulted-account"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_NewPendingTransferPayload(g, transferAmount, transferTo, Acct500_1, vaultAcct)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, uint64(1), postTxIndex-initTxIndex)

	//
	// Add another signature; total weight now is 500 + 250
	//
	events, err := MultiSig_NewPayloadSignature(g, transferAmount, transferTo, postTxIndex, Acct250_1, vaultAcct)
	assert.NoError(t, err)

	uuid, err := util.GetVaultUUID(g, vaultAcct)
	assert.NoError(t, err)
	util.NewExpectedEvent("OnChainMultiSig", "NewPayloadSigAdded").
		AddField("resourceId", strconv.Itoa(int(uuid))).
		AddField("txIndex", strconv.Itoa(int(postTxIndex))).
		AssertEqual(t, events[0])

	// This should fail because the weight is less than 1000
	_, err = MultiSig_VaultExecuteTx(g, postTxIndex, payerAcct, vaultAcct)
	assert.Error(t, err)

	//
	// Add another signature; total weight now is 500 + 250 + 500
	//
	_, err = MultiSig_NewPayloadSignature(g, transferAmount, transferTo, postTxIndex, Acct500_2, vaultAcct)
	assert.NoError(t, err)

	initFromBalance, err := util.GetBalance(g, "vaulted-account")
	assert.NoError(t, err)

	_, err = MultiSig_VaultExecuteTx(g, postTxIndex, payerAcct, vaultAcct)
	assert.NoError(t, err)

	postFromBalance, err := util.GetBalance(g, "vaulted-account")
	assert.NoError(t, err)
	assert.Equal(t, transferAmount, (initFromBalance - postFromBalance).String())
}
