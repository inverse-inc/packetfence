package main

import (
	"github.com/inverse-inc/packetfence/go/database"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// connectDB connect to the database
func connectDB(configDatabase pfconfigdriver.PfConfDatabase) {
	MySQLdatabase = database.ConnectFromConfig(configDatabase)
}
