package db

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
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

func ManualConnectDb(ctx context.Context, user, pass, host, port, dbName string) (*sql.DB, error) {
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Services)
	services := pfconfigdriver.Config.PfConf.Services
	uri := ReturnURI(ctx, user, pass, host, port, dbName, services.HaproxyDB)
	return ConnectURI(ctx, uri)
}

func DbLocalFromConfig(ctx context.Context) (*sql.DB, error) {

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Database)

	dbConfig := pfconfigdriver.Config.PfConf.Database

	return ManualConnectDb(ctx, dbConfig.User, dbConfig.Pass, "localhost", dbConfig.Port, dbConfig.Db)
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
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Services)
	services := pfconfigdriver.Config.PfConf.Services

	var DBName string
	if len(dbName) > 0 {
		DBName = dbName[0]
	} else {
		DBName = dbConfig.Db
	}

	return ReturnURI(ctx, dbConfig.User, dbConfig.Pass, dbConfig.Host, dbConfig.Port, DBName, services.HaproxyDB)
}

func ReturnURI(ctx context.Context, user, pass, host, port, dbName, haproxydb string) string {
	user = strings.TrimSpace(user)
	pass = strings.TrimSpace(pass)
	host = strings.TrimSpace(host)
	port = strings.TrimSpace(port)
	dbName = strings.TrimSpace(dbName)

	proto := "tcp"
	if sharedutils.IsEnabled(haproxydb) {
		if host == "localhost" {
			proto = "unix"
			host = "/var/lib/mysql/mysql.sock"
		}
	}

	uri := fmt.Sprintf("%s:%s@%s(%s:%s)/%s?parseTime=true&loc=Local", user, pass, proto, host, port, dbName)
	return uri
}
