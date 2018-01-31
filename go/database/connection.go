package database

import (
	"database/sql"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func Connect(user, pass, host, port, dbname string) *sql.DB {
	db, _ := sql.Open("mysql", user+":"+pass+"@tcp("+host+":"+port+")/"+dbname+"?parseTime=true")
	db.SetMaxIdleConns(0)
	db.SetMaxOpenConns(500)
	return db
}

func ConnectFromConfig(config pfconfigdriver.PfconfigDatabase) *sql.DB {
	return Connect(config.DBUser, config.DBPassword, config.DBHost, config.DBPort, config.DBName)
}
