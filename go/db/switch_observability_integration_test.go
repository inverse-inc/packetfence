package db

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"testing"
	"time"
)

// Integration coverage for the switch_observability upsert and the cache built on
// its RowsAffected contract. It runs against every backend listed in
// PF_TEST_DB_URIS ("label=dsn;label=dsn", go-sql-driver DSNs, e.g.
//
//	PF_TEST_DB_URIS='mariadb=root@unix(/var/lib/mysql/mysql.sock)/pf?parseTime=true;mysql8=root:pw@tcp(127.0.0.1:33080)/pftest?parseTime=true'
//
// or, inside the standard PacketFence test environment (addons/dev-helpers/pf-go-test.sh,
// PFCONFIG_TESTING=y), against the configured database. Without either it is skipped.
func openTestBackends(t *testing.T) map[string]*sql.DB {
	t.Helper()
	ctx := context.Background()
	backends := map[string]*sql.DB{}

	if uris := os.Getenv("PF_TEST_DB_URIS"); uris != "" {
		for entry := range strings.SplitSeq(uris, ";") {
			entry = strings.TrimSpace(entry)
			if entry == "" {
				continue
			}
			label, dsn, found := strings.Cut(entry, "=")
			if !found {
				t.Fatalf("PF_TEST_DB_URIS entry %q must be label=dsn", entry)
			}
			db, err := ConnectURI(ctx, dsn)
			if err != nil {
				t.Fatalf("%s: %v", label, err)
			}
			backends[label] = db
		}
	} else if os.Getenv("PFCONFIG_TESTING") != "" {
		db, err := DbFromConfig(ctx)
		if err != nil {
			t.Fatalf("DbFromConfig: %v", err)
		}
		backends["pfconfig"] = db
	}

	if len(backends) == 0 {
		t.Skip("set PF_TEST_DB_URIS (label=dsn;...) or run under pf-go-test.sh to exercise real backends")
	}
	return backends
}

func backendVersion(t *testing.T, db *sql.DB) string {
	t.Helper()
	var v string
	if err := db.QueryRow("SELECT VERSION()").Scan(&v); err != nil {
		t.Fatalf("SELECT VERSION(): %v", err)
	}
	return v
}

// ensureSwitchObservabilityTable mirrors db/pf-schema-X.Y.sql so a throwaway
// database (an empty MySQL container) can be used as a backend.
func ensureSwitchObservabilityTable(t *testing.T, db *sql.DB) {
	t.Helper()
	_, err := db.Exec("CREATE TABLE IF NOT EXISTS switch_observability (" +
		"`switch_id` varchar(255) PRIMARY KEY NOT NULL, " +
		"`visibility_timestamp` DATETIME default NULL" +
		") ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci'")
	if err != nil {
		t.Fatalf("create table: %v", err)
	}
}

// ageSeconds returns how old the stored visibility_timestamp is according to
// the database clock, or -1 when it is NULL.
func ageSeconds(t *testing.T, db *sql.DB, switchID string) int64 {
	t.Helper()
	var age sql.NullInt64
	err := db.QueryRow("SELECT TIMESTAMPDIFF(SECOND, visibility_timestamp, NOW()) FROM switch_observability WHERE switch_id = ?", switchID).Scan(&age)
	if err != nil {
		t.Fatalf("read visibility_timestamp: %v", err)
	}
	if !age.Valid {
		return -1
	}
	return age.Int64
}

func setAge(t *testing.T, db *sql.DB, switchID string, seconds int) {
	t.Helper()
	if _, err := db.Exec("UPDATE switch_observability SET visibility_timestamp = DATE_SUB(NOW(), INTERVAL ? SECOND) WHERE switch_id = ?", seconds, switchID); err != nil {
		t.Fatalf("age row: %v", err)
	}
}

func expectRows(t *testing.T, db *sql.DB, switchID string, want int64, what string) {
	t.Helper()
	got, err := execMarkSwitchAsSeen(db, switchID)
	if err != nil {
		t.Fatalf("%s: upsert failed: %v", what, err)
	}
	if got != want {
		t.Fatalf("%s: RowsAffected = %d, want %d", what, got, want)
	}
}

func TestIntegrationMarkSwitchAsSeenRowsAffected(t *testing.T) {
	for label, db := range openTestBackends(t) {
		t.Run(label, func(t *testing.T) {
			t.Logf("backend %s: %s", label, backendVersion(t, db))
			ensureSwitchObservabilityTable(t, db)
			id := fmt.Sprintf("go-test-%d", time.Now().UnixNano())
			db.Exec("DELETE FROM switch_observability WHERE switch_id = ?", id)
			t.Cleanup(func() { db.Exec("DELETE FROM switch_observability WHERE switch_id = ?", id) })

			// 1: brand-new row.
			expectRows(t, db, id, 1, "insert")
			if age := ageSeconds(t, db, id); age < 0 || age > 5 {
				t.Fatalf("insert: visibility_timestamp age = %d s, want ~0", age)
			}

			// 0: row exists and is fresh, must be left untouched.
			setAge(t, db, id, 20)
			expectRows(t, db, id, 0, "fresh no-op")
			if age := ageSeconds(t, db, id); age < 18 || age > 25 {
				t.Fatalf("fresh no-op: timestamp was modified, age = %d s", age)
			}

			// 2: row is older than the TTL, must be refreshed.
			setAge(t, db, id, 2*60*switchObservabilityCacheTTLInMinutes)
			expectRows(t, db, id, 2, "stale refresh")
			if age := ageSeconds(t, db, id); age < 0 || age > 5 {
				t.Fatalf("stale refresh: visibility_timestamp age = %d s, want ~0", age)
			}

			// 2: a NULL timestamp counts as stale.
			if _, err := db.Exec("UPDATE switch_observability SET visibility_timestamp = NULL WHERE switch_id = ?", id); err != nil {
				t.Fatal(err)
			}
			expectRows(t, db, id, 2, "null refresh")
			if age := ageSeconds(t, db, id); age < 0 || age > 5 {
				t.Fatalf("null refresh: visibility_timestamp age = %d s, want ~0", age)
			}
		})
	}
}

func TestIntegrationMarkSwitchAsSeenCacheWindows(t *testing.T) {
	for label, db := range openTestBackends(t) {
		t.Run(label, func(t *testing.T) {
			ensureSwitchObservabilityTable(t, db)
			id := fmt.Sprintf("go-test-cache-%d", time.Now().UnixNano())
			db.Exec("DELETE FROM switch_observability WHERE switch_id = ?", id)
			t.Cleanup(func() { db.Exec("DELETE FROM switch_observability WHERE switch_id = ?", id) })
			shard := switchObservabilityNextAllowed.Shard(id)
			expire := func() { setNextAllowed(shard, id, time.Now().Add(-time.Second), true) }
			window := func() time.Duration {
				next, ok := shard.Get(id)
				if !ok {
					t.Fatal("no cache entry after MarkSwitchAsSeen")
				}
				return time.Until(next)
			}

			// Inserted (rows=1): full TTL before the next DB round-trip.
			expire()
			if err := MarkSwitchAsSeen(db, id); err != nil {
				t.Fatal(err)
			}
			if w := window(); w < switchObservabilityCacheTTL-5*time.Second || w > switchObservabilityCacheTTL {
				t.Fatalf("after insert: window %v, want ~%v", w, switchObservabilityCacheTTL)
			}

			// Still fresh in the DB (rows=0): half TTL.
			expire()
			if err := MarkSwitchAsSeen(db, id); err != nil {
				t.Fatal(err)
			}
			if w := window(); w < switchObservabilityCacheTTL/2-5*time.Second || w > switchObservabilityCacheTTL/2 {
				t.Fatalf("after fresh no-op: window %v, want ~%v", w, switchObservabilityCacheTTL/2)
			}

			// Stale in the DB (rows=2): refreshed, full TTL again.
			setAge(t, db, id, 2*60*switchObservabilityCacheTTLInMinutes)
			expire()
			if err := MarkSwitchAsSeen(db, id); err != nil {
				t.Fatal(err)
			}
			if w := window(); w < switchObservabilityCacheTTL-5*time.Second || w > switchObservabilityCacheTTL {
				t.Fatalf("after stale refresh: window %v, want ~%v", w, switchObservabilityCacheTTL)
			}
			if age := ageSeconds(t, db, id); age < 0 || age > 5 {
				t.Fatalf("stale refresh through MarkSwitchAsSeen did not touch the row, age = %d s", age)
			}

			// Within the window: no DB access at all (a nil handle would panic).
			if err := MarkSwitchAsSeen(nil, id); err != nil {
				t.Fatalf("cached call reached the database: %v", err)
			}
		})
	}
}

// TestPerlMarkAsSeenStatementMatchesGo pins $sql_mark_as_seen in lib/pf/Switch.pm
// to markSwitchAsSeenSQL: both processes write switch_observability and rely on
// the same RowsAffected contract, so the two statements must not drift apart.
func TestPerlMarkAsSeenStatementMatchesGo(t *testing.T) {
	_, here, _, ok := runtime.Caller(0)
	if !ok {
		t.Skip("cannot locate source tree")
	}
	perlFile := filepath.Join(filepath.Dir(here), "..", "..", "lib", "pf", "Switch.pm")
	src, err := os.ReadFile(perlFile)
	if err != nil {
		t.Skipf("lib/pf/Switch.pm not available next to the Go tree: %v", err)
	}
	re := regexp.MustCompile(`(?s)my \$sql_mark_as_seen = <<"SQL";\n(.*?)\nSQL\n`)
	m := re.FindSubmatch(src)
	if m == nil {
		t.Fatalf("could not find the \\$sql_mark_as_seen heredoc in %s", perlFile)
	}
	if got, want := normalizeSQL(string(m[1])), normalizeSQL(markSwitchAsSeenSQL); got != want {
		t.Fatalf("lib/pf/Switch.pm $sql_mark_as_seen differs from go/db markSwitchAsSeenSQL\nperl: %s\ngo:   %s", got, want)
	}
}

func normalizeSQL(s string) string {
	s = strings.TrimSpace(s)
	s = strings.TrimSuffix(s, ";")
	return strings.Join(strings.Fields(s), " ")
}
