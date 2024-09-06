package db

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"
	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

const (
	charset   = "utf8mb4"
	collation = "utf8mb4_general_ci"
	sqlMode   = "NO_ENGINE_SUBSTITUTION"
)

func DbFromConfig(ctx context.Context, dbName ...string) (*sql.DB, error) {

	dbConfig := pfconfigdriver.GetType[pfconfigdriver.PfConfDatabase](ctx)

	if len(dbName) > 0 {
		return ConnectDb(ctx, dbName[0])
	} else {
		return ConnectDb(ctx, dbConfig.Db)
	}
}

func ManualConnectDb(ctx context.Context, user, pass, host, port, dbName string) (*sql.DB, error) {
	uri := ReturnURI(ctx, user, pass, host, port, dbName)
	return ConnectURI(ctx, uri)
}

func DbLocalFromConfig(ctx context.Context) (*sql.DB, error) {
	dbConfig := pfconfigdriver.GetType[pfconfigdriver.PfConfDatabase](ctx)
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
	dbConfig := pfconfigdriver.GetType[pfconfigdriver.PfConfDatabase](ctx)

	var DBName string
	if len(dbName) > 0 {
		DBName = dbName[0]
	} else {
		DBName = dbConfig.Db
	}

	return ReturnURI(ctx, dbConfig.User, dbConfig.Pass, dbConfig.Host, dbConfig.Port, DBName)
}

func ReturnURI(ctx context.Context, user, pass, host, port, dbName string) string {
	user = strings.TrimSpace(user)
	pass = strings.TrimSpace(pass)
	host = strings.TrimSpace(host)
	port = strings.TrimSpace(port)
	dbName = strings.TrimSpace(dbName)
	location, _ := time.LoadLocation("Local")

	proto := "tcp"

	if host == "localhost" {
		proto = "unix"
		host = "/var/lib/mysql/mysql.sock"
	} else {
		host = host + ":" + port
	}

	Config := mysql.NewConfig()

	Config.User = user
	Config.Passwd = pass
	Config.Net = proto
	Config.Addr = host
	Config.DBName = dbName
	Config.Collation = collation
	Config.ParseTime = true
	Config.Loc = location
	Config.Params = map[string]string{"sql_mode": sqlMode}

	return Config.FormatDSN()
}
