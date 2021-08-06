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

	pk1000 := g.Accounts["w-1000"].PrivateKey.PublicKey().String()
	signerAcct := "w-1000"
	vaultAcct := "vaulted-account"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	events, err := MultiSig_NewPendingTransferPayload(g, transferAmount, transferTo, pk1000[2:], signerAcct, vaultAcct)
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
	nra := g.Accounts["non-registered-account"].PrivateKey.PublicKey().String()
	signerAcct := "non-registered-account"
	vaultAcct := "vaulted-account"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_NewPendingTransferPayload(g, transferAmount, "owner", nra[2:], signerAcct, vaultAcct)
	assert.Error(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, uint64(0), postTxIndex-initTxIndex)
}

func TestExecutePendingTransnferFromFullAcct(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	transferAmount := "15.50000000"
	payerAcct := "owner"
	txIndex := uint64(1)

	initFromBalance, err := util.GetBalance(g, "vaulted-account")
	assert.NoError(t, err)

	_, err = MultiSig_VaultExecuteTx(g, txIndex, payerAcct)
	assert.NoError(t, err)

	postFromBalance, err := util.GetBalance(g, "vaulted-account")
	assert.NoError(t, err)

	assert.Equal(t, transferAmount, (initFromBalance - postFromBalance).String())
}

func TestExecutePayloadWithHalfAuthShouldFail(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	transferAmount := "15.50000000"
	transferTo := "owner"
	payerAcct := "owner"

	pk500_1 := g.Accounts["w-500-1"].PrivateKey.PublicKey().String()
	signerAcct1 := "w-500-1"
	vaultAcct := "vaulted-account"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	_, err = MultiSig_NewPendingTransferPayload(g, transferAmount, transferTo, pk500_1[2:], signerAcct1, vaultAcct)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, uint64(1), postTxIndex-initTxIndex)

    // This should fail because the weight is less than 500
	_, err = MultiSig_VaultExecuteTx(g, postTxIndex, payerAcct)
	assert.Error(t, err)
}
