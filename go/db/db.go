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
// Sized for ProxySQL rather than for a dedicated database. In cloud a tenant's
// whole backend budget is a few dozen connections split across capacity tiers
// (see lib/pf/services/manager/proxysql.pm), and ProxySQL multiplexes: a
// frontend connection only borrows a backend one for the duration of a
// statement. That keeps the frontend count cheap -- except for connections
// ProxySQL cannot multiplex, which are pinned to one backend for as long as
// they live. Any connection that has executed a *sql.Stmt is in that category,
// so idle connections are held in smaller numbers and are now actually reaped:
// without SetConnMaxIdleTime they were kept forever and each one pinned a
// backend connection that no other service could use.
func SetPoolLimits(db *sql.DB) {
	db.SetMaxIdleConns(2)
	db.SetMaxOpenConns(25)
	db.SetConnMaxLifetime(time.Minute * 5)
	db.SetConnMaxIdleTime(time.Minute)
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
	// Interpolate placeholders client-side so a parameterized query goes out as
	// a single COM_QUERY. Without this the driver does a server-side
	// prepare/execute/close for every query with arguments, which costs two
	// extra round trips and, more importantly, makes ProxySQL pin the backend
	// connection for the duration -- prepared statements cannot be multiplexed
	// because the statement id is scoped to one backend connection.
	//
	// Safe here: multiStatements is off, so an interpolated value cannot open a
	// second statement, and utf8mb4 is not one of the encodings the driver
	// rejects for interpolation (BIG5, CP932, GB2312, GBK, SJIS).
	Config.InterpolateParams = true
	// Bound connection establishment. Deliberately no ReadTimeout/WriteTimeout:
	// those are per-read deadlines that would kill legitimately long queries,
	// and query duration is already bounded by the per-tier ProxySQL timeouts.
	Config.Timeout = 10 * time.Second
	Config.Apply(options...)

	return Config.FormatDSN()
}
