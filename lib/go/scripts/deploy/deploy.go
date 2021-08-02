package main

import (
	"encoding/hex"
	"log"

	"github.com/bjartek/go-with-the-flow/gwtf"
	util "github.com/flow-hydraulics/onchain-multisig"
)

func main() {
	// This relative path to flow.json is  different in tests as it is the main package
	g := gwtf.NewGoWithTheFlow("../../flow.json")

	contractCode := util.ParseCadenceTemplate("../../contracts/MultiSigFlowToken.cdc")
	txFilename := "../../transactions/deploy_contract_with_auth.cdc"
	code := util.ParseCadenceTemplate(txFilename)
	encodedStr := hex.EncodeToString(contractCode)
	g.CreateAccountPrintEvents(
		"vaulted-account",
		"w-500-1",
		"w-500-2",
		"w-250-1",
		"w-250-2",
	)
	e, err := g.TransactionFromFile(txFilename, code).
		SignProposeAndPayAs("owner").
		StringArgument("MultiSigFlowToken").
		StringArgument(encodedStr).
		Run()

	if err != nil {
		log.Fatal("Cannot deploy contract")
	}

	gwtf.PrintEvents(e, map[string][]string{})
}
