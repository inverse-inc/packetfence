package database

import (
	"database/sql"
	"os"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func Connect(user, pass, host, port, dbname string) *sql.DB {
	var where string
	if host == "localhost" {
		if _, err := os.Stat("/etc/debian_version"); err == nil {
			where = "unix(/var/run/mysqld/mysqld.sock)"

		} else {
			where = "unix(/var/lib/mysql/mysql.sock)"
		}
	} else {
		where = "tcp(" + host + ":" + port + ")"
	}

	db, _ := sql.Open("mysql", user+":"+pass+"@"+where+"/"+dbname+"?parseTime=true&loc=Local")
	db.SetMaxIdleConns(0)
	db.SetMaxOpenConns(500)
	return db
}

func ConnectFromConfig(config pfconfigdriver.PfConfDatabase) *sql.DB {
	return Connect(config.User, config.Pass, config.Host, config.Port, config.Db)
}
