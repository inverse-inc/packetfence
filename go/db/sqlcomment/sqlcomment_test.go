package sqlcomment

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"strings"
	"testing"

	"github.com/inverse-inc/go-utils/log"
)

func TestDecorateServiceOnly(t *testing.T) {
	old := log.ProcessName
	log.ProcessName = "pfacct"
	defer func() { log.ProcessName = old }()

	got := decorate(context.Background(), "SELECT 1")
	want := "/* pf:pfacct */ SELECT 1"
	if got != want {
		t.Fatalf("decorate() = %q, want %q", got, want)
	}
}

func TestDecorateWithUnit(t *testing.T) {
	old := log.ProcessName
	log.ProcessName = "pfqueue"
	defer func() { log.ProcessName = old }()

	ctx := WithQueryUnit(context.Background(), "populate_ntlm_redis_cache")
	got := decorate(ctx, "UPDATE node SET x=1")
	want := "/* pf:pfqueue:populate_ntlm_redis_cache */ UPDATE node SET x=1"
	if got != want {
		t.Fatalf("decorate() = %q, want %q", got, want)
	}
}

func TestDecorateIdempotent(t *testing.T) {
	old := log.ProcessName
	log.ProcessName = "pfdns"
	defer func() { log.ProcessName = old }()

	once := decorate(context.Background(), "SELECT 1")
	twice := decorate(context.Background(), once)
	if once != twice {
		t.Fatalf("decorate not idempotent: once=%q twice=%q", once, twice)
	}
	if strings.Count(twice, "/* pf:") != 1 {
		t.Fatalf("expected exactly one remark, got %q", twice)
	}
}

func TestDecorateAlreadyDecoratedWithLeadingWhitespace(t *testing.T) {
	q := " \n\t/* pf:pfqueue */ SELECT 1"
	if got := decorate(context.Background(), q); got != q {
		t.Fatalf("decorate() modified an already-decorated query: got=%q want=%q", got, q)
	}
}

func TestServiceNameStripsPath(t *testing.T) {
	old := log.ProcessName
	log.ProcessName = "/usr/local/pf/sbin/pfstats"
	defer func() { log.ProcessName = old }()

	if got := serviceName(); got != "pfstats" {
		t.Fatalf("serviceName() = %q, want pfstats", got)
	}
}

func TestSanitizeRejectsCommentTerminatorAndJunk(t *testing.T) {
	if got := sanitize("evil*/ ; DROP"); strings.Contains(got, "*/") {
		t.Fatalf("sanitize left comment terminator: %q", got)
	}
	// spaces collapse, unsafe chars dropped
	if got := sanitize("a b;c"); got != "a_bc" {
		t.Fatalf("sanitize() = %q, want a_bc", got)
	}
}

func TestOpenUsesConnectorAndWraps(t *testing.T) {
	// sql.Open is lazy and does not connect, but because the driver implements
	// driver.DriverContext, it eagerly calls OpenConnector(dsn) -- which parses
	// the DSN. A well-formed DSN must therefore succeed without a live DB.
	db, err := sql.Open(DriverName, "u:p@tcp(127.0.0.1:3306)/test")
	if err != nil {
		t.Fatalf("sql.Open(%q): %v", DriverName, err)
	}
	defer db.Close()

	// The connector must report our wrapping driver, proving the OpenConnector
	// path (not the legacy DSN fallback) is in use.
	if _, ok := db.Driver().(wrapDriver); !ok {
		t.Fatalf("db.Driver() = %T, want wrapDriver", db.Driver())
	}
	var _ driver.DriverContext = wrapDriver{}
}
