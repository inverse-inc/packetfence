package uiplugins

import (
	"context"
	"database/sql"
	"encoding/json"
	"os"
	"testing"

	_ "github.com/go-sql-driver/mysql"
)

type registrationsFixture struct {
	Valid   []Registration `json:"valid"`
	Invalid []Registration `json:"invalid"`
}

// the cases shared with t/unittest/ui_plugins.t
func loadRegistrationsFixture(t *testing.T) registrationsFixture {
	b, err := os.ReadFile("testdata/registrations.json")
	if err != nil {
		t.Fatal(err)
	}
	f := registrationsFixture{}
	if err := json.Unmarshal(b, &f); err != nil {
		t.Fatal(err)
	}
	if len(f.Valid) == 0 || len(f.Invalid) == 0 {
		t.Fatal("empty fixture")
	}
	return f
}

func TestRegistrationValidate(t *testing.T) {
	f := loadRegistrationsFixture(t)
	for _, r := range f.Valid {
		if err := r.Validate(); err != nil {
			t.Errorf("valid registration %+v refused: %s", r, err)
		}
	}
	for _, r := range f.Invalid {
		if err := r.Validate(); err == nil {
			t.Errorf("invalid registration accepted: %+v", r)
		}
	}
	r := Registration{Name: "acme", Host: "::1", Port: 8080}
	if r.ManifestURL() != "http://[::1]:8080/manifest.json" {
		t.Errorf("unexpected manifest URL %s", r.ManifestURL())
	}
}

// UIPLUGINS_TEST_DSN is a database with the chi_cache table of
// db/pf-schema-X.Y.sql, eg: user:pass@tcp(127.0.0.1:3306)/pf
func testDB(t *testing.T) *sql.DB {
	dsn := os.Getenv("UIPLUGINS_TEST_DSN")
	if dsn == "" {
		t.Skip("UIPLUGINS_TEST_DSN is not set")
	}
	database, err := sql.Open("mysql", dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { database.Close() })
	if _, err := database.Exec("DELETE FROM chi_cache WHERE `key` LIKE ?", keyLike); err != nil {
		t.Fatal(err)
	}
	return database
}

func TestRegistry(t *testing.T) {
	ctx := context.Background()
	database := testDB(t)

	// a row of another chi_cache namespace whose key matches ui_plugins with _
	// as a LIKE wildcard
	if _, err := database.Exec("REPLACE INTO chi_cache (`key`, `value`, `expires_at`) VALUES ('uiXplugins::other', '{}', NULL)"); err != nil {
		t.Fatal(err)
	}
	defer database.Exec("DELETE FROM chi_cache WHERE `key` = 'uiXplugins::other'")

	for _, r := range loadRegistrationsFixture(t).Invalid {
		if err := RegisterDB(ctx, database, r); err == nil {
			t.Errorf("invalid registration written: %+v", r)
		}
	}

	r := Registration{Name: "acme", Host: "acme", Port: 8080}
	if err := RegisterDB(ctx, database, r); err != nil {
		t.Fatal(err)
	}
	// register again: an update
	r.Port = 8081
	if err := RegisterDB(ctx, database, r); err != nil {
		t.Fatal(err)
	}
	if err := RegisterDB(ctx, database, Registration{Name: "other", Host: "10.0.0.1", Port: 80}); err != nil {
		t.Fatal(err)
	}
	var expires sql.NullFloat64
	if err := database.QueryRow("SELECT expires_at FROM chi_cache WHERE `key` = 'ui_plugins::acme'").Scan(&expires); err != nil || expires.Valid {
		t.Errorf("expires_at must be NULL: %v %v", expires, err)
	}

	got, err := GetDB(ctx, database, "acme")
	if err != nil || got == nil || *got != r {
		t.Errorf("get: %+v %v", got, err)
	}
	if got, err := GetDB(ctx, database, "unknown"); got != nil || err != nil {
		t.Errorf("get of an unknown plugin: %+v %v", got, err)
	}

	// a row that is not a valid registration is skipped
	if _, err := database.Exec("REPLACE INTO chi_cache (`key`, `value`, `expires_at`) VALUES ('ui_plugins::bad', '{\"name\":\"bad\",\"host\":\"x y\",\"port\":1}', NULL), ('ui_plugins::moved', '{\"name\":\"acme\",\"host\":\"h\",\"port\":1}', NULL), ('ui_plugins::extra', '{\"name\":\"extra\",\"host\":\"h\",\"port\":1,\"scheme\":\"ftp\"}', NULL), ('ui_plugins::upper', '{\"NAME\":\"upper\",\"host\":\"h\",\"port\":1}', NULL), ('ui_plugins::dup', '{\"name\":\"x\",\"name\":\"dup\",\"host\":\"h\",\"port\":1}', NULL)"); err != nil {
		t.Fatal(err)
	}
	skipped := 0
	list, err := ListDB(ctx, database, func(error) { skipped++ })
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 2 || list["acme"] != r || list["other"].Host != "10.0.0.1" || skipped != 5 {
		t.Errorf("unexpected list %+v, %d skipped", list, skipped)
	}

	if err := DeregisterDB(ctx, database, "acme"); err != nil {
		t.Fatal(err)
	}
	if err := DeregisterDB(ctx, database, "acme"); err != nil {
		t.Errorf("deregister of an unknown plugin: %s", err)
	}
	if got, _ := GetDB(ctx, database, "acme"); got != nil {
		t.Error("acme still registered")
	}
	database.Exec("DELETE FROM chi_cache WHERE `key` LIKE ?", keyLike)
}
