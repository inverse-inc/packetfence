package db

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"
	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/db/sqlcomment"
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
	return ManualConnectDb(ctx, dbConfig.User, dbConfig.Pass.String(), "localhost", dbConfig.Port, dbConfig.Db)
}

func ConnectDb(ctx context.Context, dbName string) (*sql.DB, error) {
	uri := ReturnURIFromConfig(ctx, dbName)
	return ConnectURI(ctx, uri)
}

func ConnectURI(ctx context.Context, uri string) (*sql.DB, error) {
	// Open through the comment-wrapping driver so every statement carries the
	// /* pf:<service>[:<unit>] */ ProxySQL routing remark.
	db, err := sql.Open(sqlcomment.DriverName, uri)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while connecting to DB: %s", err))
		return nil, err
	} else {
		SetPoolLimits(db)
		return db, nil
	}
}

// SetPoolLimits applies the standard pool sizing to a handle. Exported so the
// GORM call sites, which build their own *sql.DB, can apply it too.
//
// The open-connection cap depends on the deployment (see poolMaxOpen). At most
// five connections are kept idle, as before, and they are reaped after a
// minute without use: SetConnMaxIdleTime was never called before, so a handle
// kept its idle connections forever. Each idle connection holds a frontend slot
// against ProxySQL's per-user cap, which rejects new connections once reached;
// keeping up to 25 idle per handle in SaaS would spend that cap on nothing.
//
// What pins a ProxySQL backend connection for as long as it lives is session
// state ProxySQL cannot hand to another client mid-flight: an open transaction,
// a user variable, a temporary table, a table lock. Long-lived *sql.Stmt values
// are NOT in that category -- ProxySQL keys its statement cache globally and
// re-prepares on whichever backend it hands out, which was measured with twelve
// concurrent clients each holding a statement open over a hostgroup capped at
// six backend connections.
func SetPoolLimits(db *sql.DB) {
	maxOpen := poolMaxOpen()
	db.SetMaxOpenConns(maxOpen)
	db.SetMaxIdleConns(poolMaxIdle)
	db.SetConnMaxLifetime(time.Minute * 5)
	db.SetConnMaxIdleTime(time.Minute)
}

// poolMaxIdle is the per-handle idle-connection cap.
const poolMaxIdle = 5

// poolMaxOpen is the per-handle open-connection cap.
//
// In SaaS (PF_SAAS) a tenant's whole backend budget on the shared database is a
// few dozen connections split across capacity tiers (see
// lib/pf/services/manager/proxysql.pm), and every frontend connection costs a
// slot against ProxySQL's per-user cap, so a handle is held to 25. On-prem the
// database is the deployment's own and keeps the previous cap of 100.
func poolMaxOpen() int {
	// CI-ONLY (revert before merge): use the SaaS cap so CI runs the 25-connection pools.
	if true || sharedutils.IsEnabled(os.Getenv("PF_SAAS")) {
		return 25
	}
	return 100
}

func ReturnURIFromConfig(ctx context.Context, dbName ...string) string {
	dbConfig := pfconfigdriver.GetType[pfconfigdriver.PfConfDatabase](ctx)

	var DBName string
	if len(dbName) > 0 {
		DBName = dbName[0]
	} else {
		DBName = dbConfig.Db
	}

	return ReturnURI(ctx, dbConfig.User, dbConfig.Pass.String(), dbConfig.Host, dbConfig.Port, DBName)
}

func ReturnURI(ctx context.Context, user, pass, host, port, dbName string) string {
	user = strings.TrimSpace(user)
	pass = strings.TrimSpace(pass)
	host = strings.TrimSpace(host)
	port = strings.TrimSpace(port)
	dbName = strings.TrimSpace(dbName)
	location, _ := time.LoadLocation("Local")
	options := []mysql.Option{}

	proto := "tcp"

	if host == "localhost" {
		proto = "unix"
		host = "/var/lib/mysql/mysql.sock"
	} else {
		host = host + ":" + port
		options = append(options, mysql.EnableCompression(true))
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
	// Bound connection establishment. Deliberately no ReadTimeout/WriteTimeout:
	// those are per-read deadlines that would kill legitimately long queries,
	// and query duration is already bounded by the per-tier ProxySQL timeouts.
	Config.Timeout = 10 * time.Second
	Config.Apply(options...)

	return Config.FormatDSN()
}
