package clientapi

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

const testSchema = `
CREATE TABLE device (mac TEXT NOT NULL, nas_ip TEXT NOT NULL DEFAULT '', ssid TEXT NOT NULL DEFAULT '', attributes TEXT NOT NULL, cache_first INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (mac, nas_ip, ssid)) STRICT;
CREATE TABLE credential (user TEXT PRIMARY KEY, data TEXT NOT NULL, expires_at INTEGER NOT NULL, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP) STRICT;
`

func sqlite(t *testing.T, db, sql string) string {
	t.Helper()
	cmd := exec.Command(sqlite3Bin, db)
	cmd.Stdin = strings.NewReader(sql)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("sqlite3: %v: %s", err, out)
	}
	return strings.TrimSpace(string(out))
}

// A snapshot of the master mirrors into the backup's live database: new and
// changed rows are taken, rows the master no longer has are removed, and the
// round trip through the encryption is transparent.
func TestCacheSnapshotMirror(t *testing.T) {
	if _, err := exec.LookPath(sqlite3Bin); err != nil {
		t.Skip("sqlite3 CLI not available")
	}
	dir := t.TempDir()
	master := filepath.Join(dir, "master.db")
	backup := filepath.Join(dir, "backup.db")
	sqlite(t, master, testSchema+`PRAGMA journal_mode=WAL;
INSERT INTO device (mac, nas_ip, ssid, attributes) VALUES ('aa:bb', '10.0.0.1', '', '{"a":1}'), ('aa:bb', '10.0.0.2', 'Corp', '{"a":2}'), ('cc:dd', '', '', '{"b":2}');
INSERT INTO credential (user, data, expires_at) VALUES ('alice', 'nt1', 100), ('bob', 'nt2', 200);`)
	sqlite(t, backup, testSchema+`PRAGMA journal_mode=WAL;
INSERT INTO device (mac, nas_ip, ssid, attributes) VALUES ('aa:bb', '10.0.0.1', '', '{"old":true}'), ('aa:bb', '10.0.0.9', '', '{"gone":1}'), ('ee:ff', '', '', '{"stale":1}');
INSERT INTO credential (user, data, expires_at) VALUES ('carol', 'stale', 1);`)

	snapshot, err := SnapshotCacheDB(master)
	if err != nil {
		t.Fatalf("snapshot: %v", err)
	}
	key := HACacheKey("secret")
	sealed, err := encryptSnapshot(key, snapshot)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}
	if _, err := decryptSnapshot(HACacheKey("other"), sealed); err == nil {
		t.Fatalf("decrypting with another key must fail")
	}
	opened, err := decryptSnapshot(key, sealed)
	if err != nil {
		t.Fatalf("decrypt: %v", err)
	}

	rows, err := ImportCacheSnapshot(backup, opened)
	if err != nil {
		t.Fatalf("import: %v", err)
	}
	if rows != 5 {
		t.Fatalf("expected 5 mirrored rows, got %d", rows)
	}
	if got := sqlite(t, backup, "SELECT attributes FROM device WHERE mac='aa:bb' AND nas_ip='10.0.0.1';"); got != `{"a":1}` {
		t.Fatalf("changed row not mirrored: %q", got)
	}
	// the composite key: the master's second context arrives, the backup's own one goes
	if got := sqlite(t, backup, "SELECT group_concat(nas_ip) FROM (SELECT nas_ip FROM device WHERE mac='aa:bb' ORDER BY nas_ip);"); got != "10.0.0.1,10.0.0.2" {
		t.Fatalf("device contexts after mirror: %q", got)
	}
	if got := sqlite(t, backup, "SELECT count(*) FROM device WHERE mac='ee:ff';"); got != "0" {
		t.Fatalf("stale device row not removed")
	}
	if got := sqlite(t, backup, "SELECT group_concat(user) FROM (SELECT user FROM credential ORDER BY user);"); got != "alice,bob" {
		t.Fatalf("credential table not mirrored: %q", got)
	}
	if _, err := ImportCacheSnapshot(backup, []byte("garbage")); err == nil {
		t.Fatalf("a non-SQLite snapshot must be refused")
	}
	if _, err := os.Stat(backup); err != nil {
		t.Fatalf("live database must still exist: %v", err)
	}
}
