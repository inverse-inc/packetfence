package db

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func DbFromConfig(ctx context.Context) (*sql.DB, error) {

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Database)

	dbConfig := pfconfigdriver.Config.PfConf.Database

	return ConnectDb(ctx, dbConfig.User, dbConfig.Pass, dbConfig.Host, dbConfig.Db)
}

func ConnectDb(ctx context.Context, user, pass, host, dbName string) (*sql.DB, error) {
	proto := "tcp"
	if host == "localhost" {
		proto = "unix"
		if _, err := os.Stat("/etc/debian_version"); err == nil {
			host = "/var/run/mysqld/mysqld.sock"

		} else {
			host = "/var/lib/mysql/mysql.sock"
		}
	}

	uri := fmt.Sprintf("%s:%s@%s(%s)/%s?parseTime=true&loc=Local", user, pass, proto, host, dbName)

	db, err := sql.Open("mysql", uri)
	db.SetMaxIdleConns(5)
	db.SetMaxOpenConns(100)
	db.SetConnMaxLifetime(time.Minute*5);
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while connecting to DB: %s", err))
		return nil, err
	} else {
		return db, nil
	}
}
