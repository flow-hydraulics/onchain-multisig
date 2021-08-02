package vault

import (
	"github.com/bjartek/go-with-the-flow/gwtf"
	util "github.com/flow-hydraulics/onchain-multisig"
	"github.com/onflow/cadence"
)

func AddVaultToAccount(
	g *gwtf.GoWithTheFlow,
	vaultAcct string,
) (events []*gwtf.FormatedEvent, err error) {
	txFilename := "../../../transactions/create_vault.cdc"
	txScript := util.ParseCadenceTemplate(txFilename)

	pk1000 := g.Accounts["w-1000"].PrivateKey.PublicKey().String()
	pk500_1 := g.Accounts["w-500-1"].PrivateKey.PublicKey().String()
	pk500_2 := g.Accounts["w-500-2"].PrivateKey.PublicKey().String()
	pk250_1 := g.Accounts["w-250-1"].PrivateKey.PublicKey().String()
	pk250_2 := g.Accounts["w-250-2"].PrivateKey.PublicKey().String()
	w1000, _ := cadence.NewUFix64("1000.0")
	w500, _ := cadence.NewUFix64("500.0")
	w250, _ := cadence.NewUFix64("250.0")

	multiSigPubKeys := []cadence.Value{
		cadence.String(pk1000),  // keyListIndex = 0
		cadence.String(pk500_1), // keyListIndex = 1
		cadence.String(pk500_2),
		cadence.String(pk250_1),
		cadence.String(pk250_2),
	}
	multiSigKeyWeights := []cadence.Value{w1000, w500, w500, w250, w250}

	e, err := g.TransactionFromFile(txFilename, txScript).
		SignProposeAndPayAs(vaultAcct).
		Argument(cadence.NewArray(multiSigPubKeys)).
		Argument(cadence.NewArray(multiSigKeyWeights)).
		Run()
	events = util.ParseTestEvents(e)
	return
}
