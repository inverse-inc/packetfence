package database

import (
	"database/sql"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func Connect(user, pass, host, port, dbname string) *sql.DB {
	var where string
	if host == "localhost" {
		where = "unix(/var/lib/mysql/mysql.sock)"
	} else {
		where = "tcp(" + host + ":" + port + ")"
	}

	db, _ := sql.Open("mysql", user+":"+pass+"@"+where+"/"+dbname+"?parseTime=true")
	db.SetMaxIdleConns(0)
	db.SetMaxOpenConns(500)
	return db
}

func ConnectFromConfig(config pfconfigdriver.PfConfDatabase) *sql.DB {
	return Connect(config.User, config.Pass, config.Host, config.Port, config.Db)
}
