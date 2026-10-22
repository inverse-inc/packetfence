package main

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"fmt"
	"io"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/inverse-inc/go-utils/log"
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

	if _, err := ip4logStatementsFor(context.Background(), db); err == nil {
		t.Fatal("the first call should report the Prepare failure")
	}

	stmts, err := ip4logStatementsFor(context.Background(), db)
	if err != nil {
		t.Fatalf("a Prepare failure must not be memoised, got %v on the retry", err)
	}

	if stmts == nil || stmts.mac2ip == nil || stmts.ip2mac == nil || stmts.ipClose == nil || stmts.ipInsert == nil {
		t.Fatalf("all four statements should be prepared: %+v", stmts)
	}

	if n := d.prepareCount(); n != 4 {
		t.Errorf("expected 4 prepared statements, got %d", n)
	}

	again, err := ip4logStatementsFor(context.Background(), db)
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
	if _, err := ip4logStatementsFor(context.Background(), firstDb); err != nil {
		t.Fatalf("first handle: %v", err)
	}

	second := &flakyDriver{}
	secondDb := openFlakyDb(t, second)
	if _, err := ip4logStatementsFor(context.Background(), secondDb); err != nil {
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

// fakeIp4logDb answers the four ip4log statements (recognized by their query
// text) so MysqlUpdateIP4Log can be driven end to end without a database.
type fakeIp4logDb struct {
	mu sync.Mutex

	// what the two conflict-detection SELECTs answer; "" means no row.
	mac2ip string
	ip2mac string
	// the error they fail with instead, standing in for a read that did not
	// happen rather than a binding that does not exist.
	selectErr error
	// RowsAffected reported by the upsert: 1 is an insert, 2 an update.
	upsertRows int64

	selects int
	closes  int
	upserts int
}

func (d *fakeIp4logDb) counts() (selects int, closes int, upserts int) {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.selects, d.closes, d.upserts
}

func (d *fakeIp4logDb) Open(string) (driver.Conn, error) { return &fakeIp4logConn{d: d}, nil }

type fakeIp4logConn struct{ d *fakeIp4logDb }

func (c *fakeIp4logConn) Prepare(query string) (driver.Stmt, error) {
	return &fakeIp4logStmt{d: c.d, query: strings.TrimSpace(query)}, nil
}

func (c *fakeIp4logConn) Close() error              { return nil }
func (c *fakeIp4logConn) Begin() (driver.Tx, error) { return nil, errors.New("not implemented") }

type fakeIp4logStmt struct {
	d     *fakeIp4logDb
	query string
}

func (s *fakeIp4logStmt) Close() error  { return nil }
func (s *fakeIp4logStmt) NumInput() int { return -1 }

func (s *fakeIp4logStmt) Query([]driver.Value) (driver.Rows, error) {
	s.d.mu.Lock()
	defer s.d.mu.Unlock()

	switch {
	case strings.HasPrefix(s.query, "SELECT ip FROM ip4log"):
		s.d.selects++
		if s.d.selectErr != nil {
			return nil, s.d.selectErr
		}

		return &fakeRows{column: "ip", value: s.d.mac2ip}, nil
	case strings.HasPrefix(s.query, "SELECT mac FROM ip4log"):
		s.d.selects++
		if s.d.selectErr != nil {
			return nil, s.d.selectErr
		}

		return &fakeRows{column: "mac", value: s.d.ip2mac}, nil
	case strings.HasPrefix(s.query, "SELECT computername FROM node"):
		return &fakeRows{column: "computername", value: s.d.mac2ip}, nil
	}

	return nil, errors.New("unexpected query: " + s.query)
}

func (s *fakeIp4logStmt) Exec([]driver.Value) (driver.Result, error) {
	s.d.mu.Lock()
	defer s.d.mu.Unlock()

	switch {
	case strings.HasPrefix(s.query, "UPDATE ip4log"):
		s.d.closes++
		return fakeResult(1), nil
	case strings.HasPrefix(s.query, "INSERT INTO ip4log"):
		s.d.upserts++
		return fakeResult(s.d.upsertRows), nil
	}

	return nil, errors.New("unexpected statement: " + s.query)
}

type fakeResult int64

func (r fakeResult) LastInsertId() (int64, error) { return 0, nil }
func (r fakeResult) RowsAffected() (int64, error) { return int64(r), nil }

// fakeRows returns a single column holding value, or no row at all when value
// is empty, which database/sql turns into sql.ErrNoRows.
type fakeRows struct {
	column string
	value  string
	done   bool
}

func (r *fakeRows) Columns() []string { return []string{r.column} }
func (r *fakeRows) Close() error      { return nil }

func (r *fakeRows) Next(dest []driver.Value) error {
	if r.done || r.value == "" {
		return io.EOF
	}

	r.done = true
	dest[0] = r.value
	return nil
}

func openFakeIp4logDb(t *testing.T, d *fakeIp4logDb) *sql.DB {
	t.Helper()
	name := fmt.Sprintf("pfdhcp-ip4log-fake-%d", time.Now().UnixNano())
	sql.Register(name, d)
	db, err := sql.Open(name, "")
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}

	t.Cleanup(func() { db.Close() })
	resetIp4logStatements()
	ip4logConflictCache.Flush()
	t.Cleanup(resetIp4logStatements)
	t.Cleanup(func() { ip4logConflictCache.Flush() })
	return db
}

func bindingExpiration(t *testing.T, mac string, ip string) int64 {
	t.Helper()
	item, found := ip4logConflictCache.Items()[ip4logConflictKey(mac, ip)]
	if !found {
		t.Fatalf("binding %s/%s is not confirmed", mac, ip)
	}

	return item.Expiration
}

const (
	testMac   = "00:11:22:33:44:10"
	testIP    = "10.0.0.20"
	testLease = 6 * time.Minute
	// what the DHCP handler passes as the ip4log validity: the lease plus its
	// own grace period.
	testDuration = testLease + time.Minute
)

// A renewal of an unchanged binding skips the two conflict SELECTs but still
// pushes end_time forward.
func TestMysqlUpdateIP4LogSkipsTheChecksForAConfirmedBinding(t *testing.T) {
	d := &fakeIp4logDb{upsertRows: 2}
	db := openFakeIp4logDb(t, d)
	ctx := log.LoggerDummyContext()

	if err := MysqlUpdateIP4Log(ctx, testMac, testIP, testDuration, testLease, db); err != nil {
		t.Fatalf("first transaction: %v", err)
	}

	if selects, _, upserts := d.counts(); selects != 2 || upserts != 1 {
		t.Fatalf("first transaction should run both checks and the upsert, got %d selects / %d upserts", selects, upserts)
	}

	if err := MysqlUpdateIP4Log(ctx, testMac, testIP, testDuration, testLease, db); err != nil {
		t.Fatalf("renewal: %v", err)
	}

	selects, _, upserts := d.counts()
	if selects != 2 {
		t.Errorf("a confirmed binding should not re-run the checks, got %d selects", selects)
	}

	if upserts != 2 {
		t.Errorf("every transaction must refresh end_time, got %d upserts", upserts)
	}
}

// The confirmation must not be renewed by the renewals it suppresses: with a
// TTL of half the lease and a client renewing at T1, re-confirming on a cache
// hit would keep the entry alive forever and the checks would never run again.
func TestMysqlUpdateIP4LogDoesNotExtendAConfirmedBinding(t *testing.T) {
	d := &fakeIp4logDb{upsertRows: 2}
	db := openFakeIp4logDb(t, d)
	ctx := log.LoggerDummyContext()

	if err := MysqlUpdateIP4Log(ctx, testMac, testIP, testDuration, testLease, db); err != nil {
		t.Fatalf("first transaction: %v", err)
	}

	deadline := bindingExpiration(t, testMac, testIP)
	time.Sleep(5 * time.Millisecond)

	if err := MysqlUpdateIP4Log(ctx, testMac, testIP, testDuration, testLease, db); err != nil {
		t.Fatalf("renewal: %v", err)
	}

	if got := bindingExpiration(t, testMac, testIP); got != deadline {
		t.Errorf("a renewal must not push the confirmation deadline forward: %d -> %d", deadline, got)
	}
}

// The TTL comes from the client's lease, not from the longer ip4log validity
// the caller derives from it: a TTL past T1 is never reached.
func TestMysqlUpdateIP4LogConfirmsForHalfTheLease(t *testing.T) {
	d := &fakeIp4logDb{upsertRows: 2}
	db := openFakeIp4logDb(t, d)

	if err := MysqlUpdateIP4Log(log.LoggerDummyContext(), testMac, testIP, testDuration, testLease, db); err != nil {
		t.Fatalf("first transaction: %v", err)
	}

	ttl := time.Duration(bindingExpiration(t, testMac, testIP) - time.Now().UnixNano())
	if want := ip4logConflictTtl(testLease); ttl > want || ttl < want-time.Second {
		t.Errorf("binding confirmed for %s, want about %s (half the lease, not half of %s)", ttl, want, testDuration)
	}
}

// A check that did not answer must not be cached away: the next transaction
// has to run it again.
func TestMysqlUpdateIP4LogDoesNotConfirmAfterAFailedCheck(t *testing.T) {
	d := &fakeIp4logDb{upsertRows: 2, selectErr: errors.New("lost connection during query")}
	db := openFakeIp4logDb(t, d)
	ctx := log.LoggerDummyContext()

	if err := MysqlUpdateIP4Log(ctx, testMac, testIP, testDuration, testLease, db); err != nil {
		t.Fatalf("first transaction: %v", err)
	}

	if ip4logBindingConfirmed(testMac, testIP) {
		t.Fatal("a binding whose conflict checks failed must not be confirmed")
	}

	if err := MysqlUpdateIP4Log(ctx, testMac, testIP, testDuration, testLease, db); err != nil {
		t.Fatalf("second transaction: %v", err)
	}

	if selects, _, _ := d.counts(); selects != 4 {
		t.Errorf("the checks should have run again, got %d selects in total", selects)
	}
}

// RowsAffected of 1 means the row had to be inserted, i.e. another writer
// removed the entry this binding relies on.
func TestMysqlUpdateIP4LogForgetsAnInsertedRow(t *testing.T) {
	d := &fakeIp4logDb{upsertRows: 1}
	db := openFakeIp4logDb(t, d)

	if err := MysqlUpdateIP4Log(log.LoggerDummyContext(), testMac, testIP, testDuration, testLease, db); err != nil {
		t.Fatalf("first transaction: %v", err)
	}

	if ip4logBindingConfirmed(testMac, testIP) {
		t.Error("a binding whose row had to be inserted must be re-checked")
	}
}

// A conflicting binding is still closed, and the binding it superseded is
// forgotten.
func TestMysqlUpdateIP4LogClosesAConflictingBinding(t *testing.T) {
	const otherMac = "00:11:22:33:44:11"

	d := &fakeIp4logDb{upsertRows: 2, ip2mac: otherMac}
	db := openFakeIp4logDb(t, d)
	confirmIp4logBinding(otherMac, testIP, testLease)

	if err := MysqlUpdateIP4Log(log.LoggerDummyContext(), testMac, testIP, testDuration, testLease, db); err != nil {
		t.Fatalf("first transaction: %v", err)
	}

	if _, closes, _ := d.counts(); closes != 1 {
		t.Errorf("the IP claimed by another MAC should have been closed, got %d closes", closes)
	}

	if ip4logBindingConfirmed(otherMac, testIP) {
		t.Error("the superseded binding must be forgotten")
	}
}

// A node row that does not exist yet must be reported as missing rather than
// as a node with no computername: the caller may not cache a host name the
// UPDATE would not have stored.
func TestMysqlGetComputername(t *testing.T) {
	d := &fakeIp4logDb{}
	db := openFakeIp4logDb(t, d)
	ctx := log.LoggerDummyContext()

	if _, found := mysqlGetComputername(ctx, testMac, db); found {
		t.Error("a node with no row must be reported as missing")
	}

	d.mac2ip = "laptop-42"
	name, found := mysqlGetComputername(ctx, testMac, db)
	if !found || name != "laptop-42" {
		t.Errorf("stored computername = %q (found %v), want \"laptop-42\"", name, found)
	}
}
