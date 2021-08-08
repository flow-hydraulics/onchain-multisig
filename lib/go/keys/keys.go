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

func MultiSig_NewRemoveSignerPayload(
	g *gwtf.GoWithTheFlow,
	acctToRemove string,
	signerAcct string,
	vaultAcct string,
) (events []*gwtf.FormatedEvent, err error) {
	txFilename := "../../../transactions/new_pending_remove_multisig_key.cdc"
	txScript := util.ParseCadenceTemplate(txFilename)

	method := "removeKey"
	pkToRemove := g.Accounts[acctToRemove].PrivateKey.PublicKey().String()
	signable, err := util.GetSignableDataFromScript(g, method, cadence.NewString(pkToRemove[2:]))
	if err != nil {
		return
	}

	sig, err := util.SignPayloadOffline(g, signable, signerAcct)
	if err != nil {
		return
	}

	signerPubKey := g.Accounts[signerAcct].PrivateKey.PublicKey().String()
	e, err := g.TransactionFromFile(txFilename, txScript).
		SignProposeAndPayAs(signerAcct).
		StringArgument(signerPubKey[2:]).
		StringArgument(sig).
		AccountArgument(vaultAcct).
		StringArgument(method).
		StringArgument(pkToRemove[2:]).
		Run()
	events = util.ParseTestEvents(e)
	return
}

func MultiSig_NewRemoveKeyPayloadSignature(
	g *gwtf.GoWithTheFlow,
	acctToRemove string,
	txIndex uint64,
	signerAcct string,
	vaultAcct string,
) (events []*gwtf.FormatedEvent, err error) {
	method := "removeKey"
	pkToRemove := g.Accounts[acctToRemove].PrivateKey.PublicKey().String()
	signable, err := util.GetSignableDataFromScript(g, method, cadence.NewString(pkToRemove[2:]))
	if err != nil {
		return
	}

	sig, err := util.SignPayloadOffline(g, signable, signerAcct)
	if err != nil {
		return
	}

	return util.MultiSigVault_NewPayloadSignature(g, txIndex, sig, signerAcct, vaultAcct)
}

func MultiSig_NewConfigSignerPayload(
	g *gwtf.GoWithTheFlow,
	acctToConfig string,
	acctToConfigWeight string,
	signerAcct string,
	vaultAcct string,
) (events []*gwtf.FormatedEvent, err error) {
	txFilename := "../../../transactions/new_pending_config_multisig_key.cdc"
	txScript := util.ParseCadenceTemplate(txFilename)

	method := "configureKey"
	pkToConfig := g.Accounts[acctToConfig].PrivateKey.PublicKey().String()
	weightToConfig, err := cadence.NewUFix64(acctToConfigWeight)
	if err != nil {
		return
	}
	signable, err := util.GetSignableDataFromScript(g, method, cadence.NewString(pkToConfig[2:]), weightToConfig)
	if err != nil {
		return
	}

	sig, err := util.SignPayloadOffline(g, signable, signerAcct)
	if err != nil {
		return
	}

	signerPubKey := g.Accounts[signerAcct].PrivateKey.PublicKey().String()
	e, err := g.TransactionFromFile(txFilename, txScript).
		SignProposeAndPayAs(signerAcct).
		StringArgument(signerPubKey[2:]).
		StringArgument(sig).
		AccountArgument(vaultAcct).
		StringArgument(method).
		StringArgument(pkToConfig[2:]).
		UFix64Argument(acctToConfigWeight).
		Run()
	events = util.ParseTestEvents(e)
	return
}
