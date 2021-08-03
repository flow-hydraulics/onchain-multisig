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

	keyListIndex, err := util.GetKeyListIndex(g, "vaulted-account")
	assert.NoError(t, err)
	assert.Equal(t, keyListIndex, uint64(5))

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

func TestAddNewPendingTransferPayload(t *testing.T) {
	g := gwtf.NewGoWithTheFlow("../../../flow.json")
	transferAmount := "15.5"
	signerKeyListIndex := 0
	signerAcct := "w-1000"
	vaultAcct := "vaulted-account"

	initTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)

	events, err := MultiSig_NewPendingTransferPayload(g, transferAmount, signerKeyListIndex, signerAcct, vaultAcct)
	assert.NoError(t, err)

	postTxIndex, err := util.GetTxIndex(g, vaultAcct)
	assert.NoError(t, err)
	assert.Equal(t, postTxIndex-initTxIndex, uint64(1))

	uuid, err := util.GetVaultUUID(g, vaultAcct)
	assert.NoError(t, err)

	util.NewExpectedEvent("OnChainMultiSig", "NewPayloadAdded").
		AddField("resourceId", strconv.Itoa(int(uuid))).
		AddField("txIndex", strconv.Itoa(int(postTxIndex))).
		AssertEqual(t, events[0])

	fmt.Println("postTxindex: ", postTxIndex)
}
