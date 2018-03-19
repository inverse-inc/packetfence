package main

import (
	"database/sql"
	"github.com/inverse-inc/packetfence/go/database"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// connectDB connect to the database
func connectDB(configDatabase pfconfigdriver.PfConfDatabase, db *sql.DB) {
	MySQLdatabase = database.ConnectFromConfig(configDatabase)
}
