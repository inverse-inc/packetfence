package db

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func DbFromConfig(ctx context.Context, dbName ...string) (*sql.DB, error) {

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Database)

	dbConfig := pfconfigdriver.Config.PfConf.Database

	if len(dbName) > 0 {
		return ConnectDb(ctx, dbName[0])
	} else {
		return ConnectDb(ctx, dbConfig.Db)
	}
}

func ConnectDb(ctx context.Context, dbName string) (*sql.DB, error) {
	uri := ReturnURI(ctx, dbName)

	db, err := sql.Open("mysql", uri)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while connecting to DB: %s", err))
		return nil, err
	} else {
		db.SetMaxIdleConns(5)
		db.SetMaxOpenConns(100)
		db.SetConnMaxLifetime(time.Minute * 5)
		return db, nil
	}
}

func ReturnURI(ctx context.Context, dbName ...string) string {

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Database)

	dbConfig := pfconfigdriver.Config.PfConf.Database
	host := dbConfig.Host
	proto := "tcp"
	if host == "localhost" {
		proto = "unix"
		if _, err := os.Stat("/etc/debian_version"); err == nil {
			host = "/var/run/mysqld/mysqld.sock"

		} else {
			host = "/var/lib/mysql/mysql.sock"
		}
	}

	var DBName string
	if len(dbName) > 0 {
		DBName = dbName[0]
	} else {
		DBName = dbConfig.Db
	}
	uri := fmt.Sprintf("%s:%s@%s(%s)/%s?parseTime=true&loc=Local", dbConfig.User, dbConfig.Pass, proto, host, DBName)
	return uri
}
