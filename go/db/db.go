package db

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-utils/log"
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

func ManualConnectDb(ctx context.Context, user, pass, host, dbName string) (*sql.DB, error) {
	uri := ReturnURI(ctx, user, pass, host, dbName)
	return ConnectURI(ctx, uri)
}

func ConnectDb(ctx context.Context, dbName string) (*sql.DB, error) {
	uri := ReturnURIFromConfig(ctx, dbName)
	return ConnectURI(ctx, uri)
}

func ConnectURI(ctx context.Context, uri string) (*sql.DB, error) {
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

func ReturnURIFromConfig(ctx context.Context, dbName ...string) string {
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Database)
	dbConfig := pfconfigdriver.Config.PfConf.Database

	var DBName string
	if len(dbName) > 0 {
		DBName = dbName[0]
	} else {
		DBName = dbConfig.Db
	}

	return ReturnURI(ctx, dbConfig.User, dbConfig.Pass, dbConfig.Host, DBName)
}

func ReturnURI(ctx context.Context, user, pass, host, dbName string) string {
	user = strings.TrimSpace(user)
	pass = strings.TrimSpace(pass)
	host = strings.TrimSpace(host)
	dbName = strings.TrimSpace(dbName)

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
	return uri
}
