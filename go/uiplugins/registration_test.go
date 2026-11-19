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

// UIPLUGINS_TEST_DSN is a database with the ui_plugin table of
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
	if _, err := database.Exec("DELETE FROM ui_plugin"); err != nil {
		t.Fatal(err)
	}
	return database
}

func TestRegistry(t *testing.T) {
	ctx := context.Background()
	database := testDB(t)

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

	got, err := GetDB(ctx, database, "acme")
	if err != nil || got == nil || *got != r {
		t.Errorf("get: %+v %v", got, err)
	}
	if got, err := GetDB(ctx, database, "unknown"); got != nil || err != nil {
		t.Errorf("get of an unknown plugin: %+v %v", got, err)
	}

	// rows written by hand that are not valid registrations are skipped
	if _, err := database.Exec("INSERT INTO ui_plugin (`name`, `host`, `port`) VALUES ('bad', 'x y', 1), ('Upper', 'h', 1), ('zero', 'h', 0)"); err != nil {
		t.Fatal(err)
	}
	if got, err := GetDB(ctx, database, "bad"); got != nil || err == nil {
		t.Errorf("get of an invalid row: %+v %v", got, err)
	}
	skipped := 0
	list, err := ListDB(ctx, database, func(error) { skipped++ })
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 2 || list["acme"] != r || list["other"].Host != "10.0.0.1" || skipped != 3 {
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
	database.Exec("DELETE FROM ui_plugin")
}
