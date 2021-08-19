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

	events, err := MultiSig_Transfer(g, transferAmount, transferTo, initTxIndex+uint64(1), Acct1000, vaultAcct, true)
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
	transferTo := "owner"
	vaultAcct := "vaulted-account"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_Transfer(g, transferAmount, transferTo, initTxIndex+uint64(1), "non-registered-account", vaultAcct, true)
	assert.Error(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, uint64(0), postTxIndex-initTxIndex)
}

func TestExecutePendingTransnferFromFullAcctOnlyOnce(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	transferAmount := "15.50000000"
	payerAcct := "owner"
	vaultAcct := "vaulted-account"

	initFromBalance, err := util.GetBalance(g, vaultAcct)
	assert.NoError(t, err)

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_VaultExecuteTx(g, initTxIndex, payerAcct, vaultAcct)
	assert.NoError(t, err)

	postFromBalance, err := util.GetBalance(g, vaultAcct)
	assert.NoError(t, err)

	assert.Equal(t, transferAmount, (initFromBalance - postFromBalance).String())

	_, err = MultiSig_VaultExecuteTx(g, initTxIndex, payerAcct, vaultAcct)
	assert.Error(t, err)
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

	_, err = MultiSig_Transfer(g, transferAmount, transferTo, initTxIndex+uint64(1), Acct500_1, vaultAcct, true)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, uint64(1), postTxIndex-initTxIndex)

	//
	// Add another signature; total weight now is 500 + 250
	//
	events, err := MultiSig_Transfer(g, transferAmount, transferTo, postTxIndex, Acct250_1, vaultAcct, false)
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
	_, err = MultiSig_Transfer(g, transferAmount, transferTo, postTxIndex, Acct500_2, vaultAcct, false)
	assert.NoError(t, err)

	initFromBalance, err := util.GetBalance(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_VaultExecuteTx(g, postTxIndex, payerAcct, vaultAcct)
	assert.NoError(t, err)

	postFromBalance, err := util.GetBalance(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, transferAmount, (initFromBalance - postFromBalance).String())
}

func TestSameAcctCannotAddMultipleSigPerTxIndex(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	transferAmount := "15.50000000"
	transferTo := "owner"

	//
	// First add a payload; total authorised weight is 500
	//
	vaultAcct := "vaulted-account"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_Transfer(g, transferAmount, transferTo, initTxIndex+uint64(1), Acct500_1, vaultAcct, true)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, uint64(1), postTxIndex-initTxIndex)

	//
	// Add another signature; total weight now is 500 + 250
	//
	_, err = MultiSig_Transfer(g, transferAmount, transferTo, postTxIndex, Acct250_1, vaultAcct, false)
	assert.NoError(t, err)

	// Same account cannot add signature again
	_, err = MultiSig_Transfer(g, transferAmount, transferTo, postTxIndex, Acct250_1, vaultAcct, false)
	assert.Error(t, err)

}

func TestDepositWithFullMultiSigAccount(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	transferAmount := "15.50000000"
	vaultAcct := "vaulted-account"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = AddVaultToAccount(g, Acct1000)
	assert.NoError(t, err)

	// give one of the multisig signers some tokens
	seedAmount := "100.00000000"
	_, err = AccountSignerTransferTokens(g, seedAmount, "owner", Acct1000)
	assert.NoError(t, err)

	balanceA, err := util.GetBalance(g, Acct1000)
	assert.NoError(t, err)

	balanceAV, err := util.GetBalance(g, vaultAcct)
	assert.NoError(t, err)

	// transferAmount will come out of the acct who adds the payload, Acct1000
	_, err = MultiSig_Deposit(g, transferAmount, initTxIndex+uint64(1), Acct1000, vaultAcct, true)
	assert.NoError(t, err)

	balanceB, err := util.GetBalance(g, Acct1000)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, uint64(1), postTxIndex-initTxIndex)

	events, err := MultiSig_VaultExecuteTx(g, postTxIndex, "owner", vaultAcct)
	assert.NoError(t, err)

	balanceBV, err := util.GetBalance(g, vaultAcct)
	assert.NoError(t, err)

	fmt.Println("execution: ", events)
	fmt.Println("balanceBV: ", balanceBV)
	fmt.Println("balanceAV: ", balanceAV)

	assert.Equal(t, transferAmount, (balanceA - balanceB).String())
	assert.Equal(t, transferAmount, (balanceBV - balanceAV).String())
}

func TestRemoveResourceWithFullMultiSigAccount(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	transferAmount := "15.50000000"
	vaultAcct := "vaulted-account"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	balanceA, err := util.GetBalance(g, Acct1000)
	assert.NoError(t, err)

	ownerBalanceA, err := util.GetBalance(g, "owner")
	assert.NoError(t, err)

	// transferAmount will come out of the acct who adds the payload, Acct1000
	_, err = MultiSig_Deposit(g, transferAmount, initTxIndex+uint64(1), Acct1000, vaultAcct, true)
	assert.NoError(t, err)

	balanceB, err := util.GetBalance(g, Acct1000)
	assert.NoError(t, err)

	indexToRemove, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_RemoveVaultedPayload(g, indexToRemove+uint64(1), indexToRemove, Acct1000, vaultAcct, true)
	assert.NoError(t, err)

	_, err = MultiSig_VaultExecuteTx(g, indexToRemove+uint64(1), "owner", vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_VaultExecuteTx(g, indexToRemove, "owner", vaultAcct)
	assert.Error(t, err)

	ownerBalanceB, err := util.GetBalance(g, "owner")
	assert.NoError(t, err)

	assert.Equal(t, transferAmount, (balanceA - balanceB).String())
	assert.Equal(t, transferAmount, (ownerBalanceB - ownerBalanceA).String())
}
