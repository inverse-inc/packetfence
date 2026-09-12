package main

import (
	"database/sql"
	"database/sql/driver"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"
)

// flakyDriver is a database/sql driver whose Prepare fails the first
// failPrepares times, standing in for a database that is not accepting
// connections yet when pfdhcp handles its first DHCP transaction.
type flakyDriver struct {
	mu           sync.Mutex
	failPrepares int
	prepared     int
}

func (d *flakyDriver) Open(string) (driver.Conn, error) { return &flakyConn{d: d}, nil }

type flakyConn struct{ d *flakyDriver }

func (c *flakyConn) Prepare(string) (driver.Stmt, error) {
	c.d.mu.Lock()
	defer c.d.mu.Unlock()
	if c.d.failPrepares > 0 {
		c.d.failPrepares--
		return nil, errors.New("database is starting up")
	}

	c.d.prepared++
	return &flakyStmt{}, nil
}

func (c *flakyConn) Close() error              { return nil }
func (c *flakyConn) Begin() (driver.Tx, error) { return nil, errors.New("not implemented") }

type flakyStmt struct{}

func (s *flakyStmt) Close() error  { return nil }
func (s *flakyStmt) NumInput() int { return -1 }
func (s *flakyStmt) Exec([]driver.Value) (driver.Result, error) {
	return nil, errors.New("not implemented")
}
func (s *flakyStmt) Query([]driver.Value) (driver.Rows, error) {
	return nil, errors.New("not implemented")
}

func (d *flakyDriver) prepareCount() int {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.prepared
}

func openFlakyDb(t *testing.T, d *flakyDriver) *sql.DB {
	t.Helper()
	name := fmt.Sprintf("pfdhcp-ip4log-test-%d", time.Now().UnixNano())
	sql.Register(name, d)
	db, err := sql.Open(name, "")
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}

	t.Cleanup(func() { db.Close() })
	return db
}

func resetIp4logStatements() {
	ip4logStmtsMu.Lock()
	defer ip4logStmtsMu.Unlock()
	ip4logStmts, ip4logStmtsDb = nil, nil
}

// A failed Prepare must not be remembered: sql.Open does not connect, so the
// first Prepare is also the first connection attempt, and memoising its error
// left every later ip4log write failing until pfdhcp was restarted.
func TestIp4logStatementsForRetriesAfterAPrepareFailure(t *testing.T) {
	resetIp4logStatements()
	t.Cleanup(resetIp4logStatements)

	d := &flakyDriver{failPrepares: 1}
	db := openFlakyDb(t, d)

	if _, err := ip4logStatementsFor(db); err == nil {
		t.Fatal("the first call should report the Prepare failure")
	}

	stmts, err := ip4logStatementsFor(db)
	if err != nil {
		t.Fatalf("a Prepare failure must not be memoised, got %v on the retry", err)
	}

	if stmts == nil || stmts.mac2ip == nil || stmts.ip2mac == nil || stmts.ipClose == nil || stmts.ipInsert == nil {
		t.Fatalf("all four statements should be prepared: %+v", stmts)
	}

	if n := d.prepareCount(); n != 4 {
		t.Errorf("expected 4 prepared statements, got %d", n)
	}

	again, err := ip4logStatementsFor(db)
	if err != nil {
		t.Fatalf("third call: %v", err)
	}

	if again != stmts {
		t.Error("statements should be reused for the same handle, not prepared again")
	}

	if n := d.prepareCount(); n != 4 {
		t.Errorf("reuse should not prepare again, got %d statements", n)
	}
}

// The statements are bound to the handle they were prepared against, so a
// different handle must re-prepare rather than silently keep using the old one.
func TestIp4logStatementsForRepreparesForANewHandle(t *testing.T) {
	resetIp4logStatements()
	t.Cleanup(resetIp4logStatements)

	first := &flakyDriver{}
	firstDb := openFlakyDb(t, first)
	if _, err := ip4logStatementsFor(firstDb); err != nil {
		t.Fatalf("first handle: %v", err)
	}

	second := &flakyDriver{}
	secondDb := openFlakyDb(t, second)
	if _, err := ip4logStatementsFor(secondDb); err != nil {
		t.Fatalf("second handle: %v", err)
	}

	if n := second.prepareCount(); n != 4 {
		t.Errorf("a new handle should prepare its own statements, got %d", n)
	}
}

func TestIp4logConflictTtl(t *testing.T) {
	cases := []struct {
		name  string
		lease time.Duration
		want  time.Duration
	}{
		{"half the lease", 10 * time.Minute, 5 * time.Minute},
		{"typical 5 minute lease", 5 * time.Minute, 150 * time.Second},
		{"long lease is capped", 24 * time.Hour, ip4logConflictTtlMax},
		{"short lease keeps the floor", 10 * time.Second, ip4logConflictTtlMin},
		{"zero lease keeps the floor", 0, ip4logConflictTtlMin},
		{"negative lease keeps the floor", -time.Minute, ip4logConflictTtlMin},
	}

	for _, c := range cases {
		if got := ip4logConflictTtl(c.lease); got != c.want {
			t.Errorf("%s: ip4logConflictTtl(%s) = %s, want %s", c.name, c.lease, got, c.want)
		}
	}
}

// The conflict checks are skipped only for the exact MAC<->IP pair that was
// confirmed; every way a binding can change is a different key, and closing a
// superseded row forgets the binding it belonged to.
func TestIp4logBindingCache(t *testing.T) {
	const (
		macA = "00:11:22:33:44:01"
		macB = "00:11:22:33:44:02"
		ipA  = "10.0.0.10"
		ipB  = "10.0.0.11"
	)

	t.Cleanup(func() { ip4logConflictCache.Flush() })
	ip4logConflictCache.Flush()

	if ip4logBindingConfirmed(macA, ipA) {
		t.Fatal("an unseen binding must not be confirmed")
	}

	confirmIp4logBinding(macA, ipA, 10*time.Minute)
	if !ip4logBindingConfirmed(macA, ipA) {
		t.Fatal("the binding should be confirmed after a successful upsert")
	}

	// Same device, new IP: a different key, so the checks run again.
	if ip4logBindingConfirmed(macA, ipB) {
		t.Error("a new IP for the same MAC must not be confirmed")
	}

	// Same IP, new device: also a different key.
	if ip4logBindingConfirmed(macB, ipA) {
		t.Error("a new MAC for the same IP must not be confirmed")
	}

	// Closing the row that macB took over forgets only that binding.
	confirmIp4logBinding(macB, ipB, 10*time.Minute)
	forgetIp4logBinding(macA, ipA)
	if ip4logBindingConfirmed(macA, ipA) {
		t.Error("a forgotten binding must be re-checked")
	}

	if !ip4logBindingConfirmed(macB, ipB) {
		t.Error("forgetting one binding must not drop the others")
	}
}

func TestIp4logBindingCacheExpires(t *testing.T) {
	const (
		mac = "00:11:22:33:44:03"
		ip  = "10.0.0.12"
	)

	t.Cleanup(func() { ip4logConflictCache.Flush() })
	ip4logConflictCache.Flush()

	// ip4logConflictTtl floors at 30s, so set the short entry directly.
	ip4logConflictCache.Set(ip4logConflictKey(mac, ip), 1, 10*time.Millisecond)
	if !ip4logBindingConfirmed(mac, ip) {
		t.Fatal("the binding should be confirmed right after it is set")
	}

	time.Sleep(30 * time.Millisecond)
	if ip4logBindingConfirmed(mac, ip) {
		t.Error("the binding should be re-checked once the entry expires")
	}
}
