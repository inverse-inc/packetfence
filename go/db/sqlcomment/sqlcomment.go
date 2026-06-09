// Package sqlcomment provides a database/sql driver that wraps the
// go-sql-driver/mysql driver and prepends a ProxySQL routing remark to every
// statement it executes.
//
// The remark has the form:
//
//	/* pf:<service>[:<unit>] */ <SQL>
//
// where <service> is the running binary (log.ProcessName) and <unit> is an
// optional logical work-unit (a cron job name or queue task type) carried on
// the context via WithQueryUnit. ProxySQL query rules can then route each
// (service[,unit]) bucket to its own hostgroup with a dedicated max_connections
// cap, using a match_pattern anchored on `^/\* pf:` (match_digest strips
// comments and must not be used).
//
// The driver is registered under DriverName ("mysql-pf"). Use it exactly like
// the "mysql" driver: sql.Open(sqlcomment.DriverName, dsn), or for GORM
// mysql.New(mysql.Config{DriverName: sqlcomment.DriverName, DSN: dsn}).
package sqlcomment

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"strings"

	"github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-utils/log"
)

// DriverName is the name the wrapped driver is registered under.
const DriverName = "mysql-pf"

func init() {
	sql.Register(DriverName, wrapDriver{mysql.MySQLDriver{}})
}

type unitCtxKey struct{}

// WithQueryUnit returns a context carrying the logical work-unit name that the
// routing remark should advertise (=> /* pf:<service>:<unit> */). Stamp it at a
// job/task dispatch point and thread the ctx into the DB calls.
func WithQueryUnit(ctx context.Context, unit string) context.Context {
	return context.WithValue(ctx, unitCtxKey{}, unit)
}

func unitFromContext(ctx context.Context) string {
	if ctx == nil {
		return ""
	}
	if v, ok := ctx.Value(unitCtxKey{}).(string); ok {
		return v
	}
	return ""
}

// decorate prepends the routing remark unless the query is already decorated.
func decorate(ctx context.Context, query string) string {
	// Treat leading whitespace as insignificant for idempotency since callers may indent multi-line SQL.
	if strings.HasPrefix(strings.TrimLeft(query, " \t\r\n"), "/* pf:") {
		return query
	}
	tag := "pf:" + sanitize(serviceName())
	if u := sanitize(unitFromContext(ctx)); u != "" {
		tag += ":" + u
	}
	return "/* " + tag + " */ " + query
}

func serviceName() string {
	n := log.ProcessName
	// ProcessName defaults to os.Args[0], which may be a path.
	if i := strings.LastIndexAny(n, `/\`); i >= 0 {
		n = n[i+1:]
	}
	if n == "" {
		return "unknown"
	}
	return n
}

// sanitize makes a value safe to embed in a SQL comment and unambiguous for a
// ProxySQL regex: it can never contain the comment terminator, and keeps only
// routing-safe characters.
func sanitize(v string) string {
	v = strings.ReplaceAll(v, "*/", "")
	var b strings.Builder
	for _, r := range v {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9',
			r == '_', r == '-', r == '/', r == '.':
			b.WriteRune(r)
		case r == ' ' || r == '\t' || r == '\n' || r == '\r':
			b.WriteRune('_')
		}
	}
	return b.String()
}

// wrapDriver wraps a driver.Driver so every opened connection is a wrapConn.
type wrapDriver struct{ driver.Driver }

func (d wrapDriver) Open(dsn string) (driver.Conn, error) {
	c, err := d.Driver.Open(dsn)
	if err != nil {
		return nil, err
	}
	return wrapConn{c}, nil
}

// wrapConn forwards every connection method to the underlying mysql connection,
// decorating the SQL on the query/exec/prepare paths. It re-implements the
// optional database/sql driver interfaces (context exec, transactions, pooling
// hooks, arg checking, validity) so wrapping does not silently disable mysql
// behavior.
type wrapConn struct{ driver.Conn }

var (
	_ driver.QueryerContext     = wrapConn{}
	_ driver.ExecerContext      = wrapConn{}
	_ driver.ConnPrepareContext = wrapConn{}
	_ driver.ConnBeginTx        = wrapConn{}
	_ driver.Pinger             = wrapConn{}
	_ driver.SessionResetter    = wrapConn{}
	_ driver.Validator          = wrapConn{}
	_ driver.NamedValueChecker  = wrapConn{}
)

func (c wrapConn) Prepare(query string) (driver.Stmt, error) {
	return c.Conn.Prepare(decorate(context.Background(), query))
}

func (c wrapConn) PrepareContext(ctx context.Context, query string) (driver.Stmt, error) {
	if p, ok := c.Conn.(driver.ConnPrepareContext); ok {
		return p.PrepareContext(ctx, decorate(ctx, query))
	}
	return c.Conn.Prepare(decorate(ctx, query))
}

func (c wrapConn) QueryContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Rows, error) {
	q, ok := c.Conn.(driver.QueryerContext)
	if !ok {
		// Let database/sql fall back to the Prepare path (which we decorate).
		return nil, driver.ErrSkip
	}
	return q.QueryContext(ctx, decorate(ctx, query), args)
}

func (c wrapConn) ExecContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Result, error) {
	e, ok := c.Conn.(driver.ExecerContext)
	if !ok {
		return nil, driver.ErrSkip
	}
	return e.ExecContext(ctx, decorate(ctx, query), args)
}

func (c wrapConn) BeginTx(ctx context.Context, opts driver.TxOptions) (driver.Tx, error) {
	if b, ok := c.Conn.(driver.ConnBeginTx); ok {
		return b.BeginTx(ctx, opts)
	}
	return c.Conn.Begin()
}

func (c wrapConn) Ping(ctx context.Context) error {
	if p, ok := c.Conn.(driver.Pinger); ok {
		return p.Ping(ctx)
	}
	return nil
}

func (c wrapConn) ResetSession(ctx context.Context) error {
	if r, ok := c.Conn.(driver.SessionResetter); ok {
		return r.ResetSession(ctx)
	}
	return nil
}

func (c wrapConn) IsValid() bool {
	if v, ok := c.Conn.(driver.Validator); ok {
		return v.IsValid()
	}
	return true
}

func (c wrapConn) CheckNamedValue(nv *driver.NamedValue) error {
	if ck, ok := c.Conn.(driver.NamedValueChecker); ok {
		return ck.CheckNamedValue(nv)
	}
	// No custom checker: let database/sql apply its default conversion.
	return driver.ErrSkip
}
