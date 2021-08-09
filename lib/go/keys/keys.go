package keys

import (
	"github.com/bjartek/go-with-the-flow/gwtf"
	util "github.com/flow-hydraulics/onchain-multisig"
	"github.com/onflow/cadence"
)

func ContainsKey(g *gwtf.GoWithTheFlow, resourceAcct string, key string) (result bool, err error) {
	keys, err := util.GetStoreKeys(g, resourceAcct)
	result = false
	for _, k := range keys {
		if k == key {
			result = true
			return
		}
	}
	return
}

func MultiSig_RemoveKey(
	g *gwtf.GoWithTheFlow,
	acctToRemove string,
	txIndex uint64,
	signerAcct string,
	vaultAcct string,
	newPayload bool,
) (events []*gwtf.FormatedEvent, err error) {
	method := "removeKey"
	pkToRemove := cadence.NewString(g.Accounts[acctToRemove].PrivateKey.PublicKey().String()[2:])
	signable, err := util.GetSignableDataFromScript(g, txIndex, method, pkToRemove)
	if err != nil {
		return
	}

	sig, err := util.SignPayloadOffline(g, signable, signerAcct)
	if err != nil {
		return
	}

	if newPayload {
		args := []cadence.Value{pkToRemove}
		return util.MultiSig_VaultNewPayload(g, sig, txIndex, method, args, signerAcct, vaultAcct)
	} else {
		return util.MultiSig_VaultAddPayloadSignature(g, sig, txIndex, signerAcct, vaultAcct)
	}
}

func MultiSig_ConfigKey(
	g *gwtf.GoWithTheFlow,
	acctToConfig string,
	acctToConfigWeight string,
	txIndex uint64,
	signerAcct string,
	vaultAcct string,
	newPayload bool,
) (events []*gwtf.FormatedEvent, err error) {

	method := "configureKey"
	pkToConfig := cadence.NewString(g.Accounts[acctToConfig].PrivateKey.PublicKey().String()[2:])

	weightToConfig, err := cadence.NewUFix64(acctToConfigWeight)
	if err != nil {
		return
	}
	signable, err := util.GetSignableDataFromScript(g, txIndex, method, pkToConfig, weightToConfig)
	if err != nil {
		return
	}

	sig, err := util.SignPayloadOffline(g, signable, signerAcct)
	if err != nil {
		return
	}

	if newPayload {
		args := []cadence.Value{pkToConfig, weightToConfig}
		return util.MultiSig_VaultNewPayload(g, sig, txIndex, method, args, signerAcct, vaultAcct)
	} else {
		return util.MultiSig_VaultAddPayloadSignature(g, sig, txIndex, signerAcct, vaultAcct)
	}
}
