package main

import (
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

// connectDB connect to the database
func connectDB(configDatabase pfconfigdriver.PfConfDatabase) {
	db, err := db.DbFromConfig(ctx)
	sharedutils.CheckError(err)
	MySQLdatabase = db
}
