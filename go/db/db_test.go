package db

import (
	"context"
	"database/sql"
	"strings"
	"testing"
)

// The DSN settings below are load-bearing for ProxySQL, and nothing else in the
// build would notice if they were dropped, so pin them here.

func TestReturnURIInterpolatesParams(t *testing.T) {
	// Without interpolateParams the driver turns every parameterized query into
	// a server-side prepare, which ProxySQL cannot multiplex: it has to pin the
	// backend connection for the prepare/execute pair.
	uri := ReturnURI(context.Background(), "pf", "secret", "100.64.0.1", "6033", "pf")
	if !strings.Contains(uri, "interpolateParams=true") {
		t.Fatalf("DSN is missing interpolateParams=true: %s", uri)
	}
}

func TestReturnURIDoesNotEnableMultiStatements(t *testing.T) {
	// interpolateParams is only safe to use while multiStatements is off --
	// otherwise an interpolated value could open a second statement.
	uri := ReturnURI(context.Background(), "pf", "secret", "100.64.0.1", "6033", "pf")
	if strings.Contains(uri, "multiStatements=true") {
		t.Fatalf("multiStatements must stay off while interpolateParams is on: %s", uri)
	}
}

func TestReturnURICollationIsInterpolationSafe(t *testing.T) {
	// go-sql-driver refuses to interpolate under these encodings, because a
	// multibyte sequence could swallow the closing quote.
	uri := ReturnURI(context.Background(), "pf", "secret", "100.64.0.1", "6033", "pf")
	for _, unsafe := range []string{"big5", "cp932", "gb2312", "gbk", "sjis"} {
		if strings.Contains(strings.ToLower(uri), unsafe) {
			t.Fatalf("collation %q cannot be used with interpolateParams: %s", unsafe, uri)
		}
	}
}

func TestReturnURIHasConnectTimeout(t *testing.T) {
	uri := ReturnURI(context.Background(), "pf", "secret", "100.64.0.1", "6033", "pf")
	if !strings.Contains(uri, "timeout=") {
		t.Fatalf("DSN is missing a connect timeout: %s", uri)
	}
	// A per-read deadline would kill legitimately long queries; query duration
	// is bounded by the per-tier ProxySQL timeouts instead.
	for _, unwanted := range []string{"readTimeout=", "writeTimeout="} {
		if strings.Contains(uri, unwanted) {
			t.Fatalf("DSN should not set %s: %s", unwanted, uri)
		}
	}
}

func TestReturnURIUsesSocketForLocalhost(t *testing.T) {
	uri := ReturnURI(context.Background(), "pf", "secret", "localhost", "3306", "pf")
	if !strings.Contains(uri, "unix(") {
		t.Fatalf("localhost should connect over the unix socket: %s", uri)
	}
}

func TestSetPoolLimitsStaysWithinTierBudget(t *testing.T) {
	// A tenant's entire backend budget across all capacity tiers is a few dozen
	// connections (lib/pf/services/manager/proxysql.pm), shared by every
	// service. A single handle must not be able to claim all of it.
	db := &sql.DB{}
	SetPoolLimits(db)

	stats := db.Stats()
	if stats.MaxOpenConnections <= 0 {
		t.Fatal("MaxOpenConns must be bounded, not unlimited")
	}
	if stats.MaxOpenConnections > 25 {
		t.Fatalf("MaxOpenConns = %d, too large for the per-tier budget", stats.MaxOpenConnections)
	}
}
