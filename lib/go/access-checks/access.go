package access

import (
	"github.com/bjartek/go-with-the-flow/gwtf"
	util "github.com/flow-hydraulics/onchain-multisig"
)

func MultiSig_PubUpdateKeyList(
	g *gwtf.GoWithTheFlow,
	payerAcct string,
	vaultAcct string,
) (events []*gwtf.FormatedEvent, err error) {
	txFilename := "../../../transactions/pubUpdateKeyList.cdc"
	txScript := util.ParseCadenceTemplate(txFilename)

	e, err := g.TransactionFromFile(txFilename, txScript).
		SignProposeAndPayAs(payerAcct).
		AccountArgument(vaultAcct).
		Run()
	events = util.ParseTestEvents(e)
	return
}

func MultiSig_PubUpdateTxIndex(
	g *gwtf.GoWithTheFlow,
	index uint64,
	payerAcct string,
	vaultAcct string,
) (events []*gwtf.FormatedEvent, err error) {
	txFilename := "../../../transactions/pubUpdateTxIndex.cdc"
	txScript := util.ParseCadenceTemplate(txFilename)

	e, err := g.TransactionFromFile(txFilename, txScript).
		SignProposeAndPayAs(payerAcct).
		AccountArgument(vaultAcct).
		UInt64Argument(index).
		Run()
	events = util.ParseTestEvents(e)
	return
}

func MultiSig_PubUpdateStore(
	g *gwtf.GoWithTheFlow,
	index uint64,
	payerAcct string,
	vaultAcct string,
) (events []*gwtf.FormatedEvent, err error) {
	txFilename := "../../../transactions/pubUpdateStore.cdc"
	txScript := util.ParseCadenceTemplate(txFilename)

	e, err := g.TransactionFromFile(txFilename, txScript).
		SignProposeAndPayAs(payerAcct).
		AccountArgument(vaultAcct).
		UInt64Argument(index).
		Run()
	events = util.ParseTestEvents(e)
	return
}

func MultiSig_OwnerUpdateKeyList(
	g *gwtf.GoWithTheFlow,
	payerAcct string,
	vaultAcct string,
) (events []*gwtf.FormatedEvent, err error) {
	txFilename := "../../../transactions/ownerUpdateKeyList.cdc"
	txScript := util.ParseCadenceTemplate(txFilename)

	e, err := g.TransactionFromFile(txFilename, txScript).
		SignProposeAndPayAs(payerAcct).
		AccountArgument(vaultAcct).
		Run()
	events = util.ParseTestEvents(e)
	return
}

func MultiSig_OwnerUpdateTxIndex(
	g *gwtf.GoWithTheFlow,
	index uint64,
	payerAcct string,
	vaultAcct string,
) (events []*gwtf.FormatedEvent, err error) {
	txFilename := "../../../transactions/ownerUpdateTxIndex.cdc"
	txScript := util.ParseCadenceTemplate(txFilename)

	e, err := g.TransactionFromFile(txFilename, txScript).
		SignProposeAndPayAs(payerAcct).
		AccountArgument(vaultAcct).
		UInt64Argument(index).
		Run()
	events = util.ParseTestEvents(e)
	return
}

func MultiSig_OwnerUpdateStore(
	g *gwtf.GoWithTheFlow,
	index uint64,
	payerAcct string,
	vaultAcct string,
) (events []*gwtf.FormatedEvent, err error) {
	txFilename := "../../../transactions/ownerUpdateStore.cdc"
	txScript := util.ParseCadenceTemplate(txFilename)

	e, err := g.TransactionFromFile(txFilename, txScript).
		SignProposeAndPayAs(payerAcct).
		AccountArgument(vaultAcct).
		UInt64Argument(index).
		Run()
	events = util.ParseTestEvents(e)
	return
}
