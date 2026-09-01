package main

import (
	"context"
	"testing"

	"github.com/inverse-inc/go-utils/mac"
)

func TestUpdateNodeLastSeen(t *testing.T) {
	pfAcct := NewPfAcct("INFO")
	if pfAcct == nil {
		t.Fatalf("New pfAcct")
	}
	ctx := context.Background()

	m, _ := mac.NewFromString("99:77:55:44:33:23")
	if _, err := pfAcct.Db.Exec("DELETE FROM node WHERE mac = ?", m.String()); err != nil {
		t.Fatalf("%s", err.Error())
	}
	if _, err := pfAcct.Db.Exec("INSERT INTO node (mac, status, last_seen) VALUES (?, 'unreg', DATE_SUB(NOW(), INTERVAL 1 DAY))", m.String()); err != nil {
		t.Fatalf("%s", err.Error())
	}

	pfAcct.updateNodeLastSeen(ctx, m)

	var fresh int
	err := pfAcct.Db.QueryRow("SELECT 1 FROM node WHERE mac = ? AND last_seen > DATE_SUB(NOW(), INTERVAL 1 MINUTE)", m.String()).Scan(&fresh)
	if err != nil {
		t.Fatalf("last_seen was not refreshed: %s", err.Error())
	}

	// The refresh is rate-limited per MAC: age the row again and verify a
	// second call within the TTL does not touch it.
	if _, err := pfAcct.Db.Exec("UPDATE node SET last_seen = DATE_SUB(NOW(), INTERVAL 1 DAY) WHERE mac = ?", m.String()); err != nil {
		t.Fatalf("%s", err.Error())
	}
	pfAcct.updateNodeLastSeen(ctx, m)
	err = pfAcct.Db.QueryRow("SELECT 1 FROM node WHERE mac = ? AND last_seen > DATE_SUB(NOW(), INTERVAL 1 MINUTE)", m.String()).Scan(&fresh)
	if err == nil {
		t.Fatalf("last_seen refresh was not rate-limited")
	}
}

func TestUpdateIp4log(t *testing.T) {
	pfAcct := NewPfAcct("INFO")
	if pfAcct == nil {
		t.Fatalf("New pfAcct")
	}
	ctx := context.Background()
	pfAcct.UpdateIplogWithAccounting = true

	m, _ := mac.NewFromString("99:77:55:44:33:24")
	ip1, ip2 := "198.51.100.61", "198.51.100.62"
	for _, ip := range []string{ip1, ip2} {
		if _, err := pfAcct.Db.Exec("DELETE FROM ip4log WHERE ip = ?", ip); err != nil {
			t.Fatalf("%s", err.Error())
		}
	}
	if _, err := pfAcct.Db.Exec("DELETE FROM node WHERE mac = ?", m.String()); err != nil {
		t.Fatalf("%s", err.Error())
	}

	// Unknown node: the entry must be created (ip4log needs the node row)
	// and the ip4log entry opened with the zero end_time.
	pfAcct.updateIp4log(ctx, m, ip1)

	var one int
	if err := pfAcct.Db.QueryRow("SELECT 1 FROM node WHERE mac = ?", m.String()).Scan(&one); err != nil {
		t.Fatalf("node was not auto-created: %s", err.Error())
	}
	if err := pfAcct.Db.QueryRow("SELECT 1 FROM ip4log WHERE ip = ? AND mac = ? AND end_time = '0000-00-00 00:00:00'", ip1, m.String()).Scan(&one); err != nil {
		t.Fatalf("ip4log entry for %s was not opened: %s", ip1, err.Error())
	}

	// IP change: the old entry closes, the new one opens.
	pfAcct.updateIp4log(ctx, m, ip2)

	if err := pfAcct.Db.QueryRow("SELECT 1 FROM ip4log WHERE ip = ? AND end_time != '0000-00-00 00:00:00'", ip1).Scan(&one); err != nil {
		t.Fatalf("old ip4log entry for %s was not closed: %s", ip1, err.Error())
	}
	if err := pfAcct.Db.QueryRow("SELECT 1 FROM ip4log WHERE ip = ? AND mac = ? AND end_time = '0000-00-00 00:00:00'", ip2, m.String()).Scan(&one); err != nil {
		t.Fatalf("ip4log entry for %s was not opened: %s", ip2, err.Error())
	}

	// Same MAC/IP within the TTL is skipped (rate-limited): removing the row
	// behind the cache's back and re-calling must not recreate it.
	if _, err := pfAcct.Db.Exec("DELETE FROM ip4log WHERE ip = ?", ip2); err != nil {
		t.Fatalf("%s", err.Error())
	}
	pfAcct.updateIp4log(ctx, m, ip2)
	if err := pfAcct.Db.QueryRow("SELECT 1 FROM ip4log WHERE ip = ?", ip2).Scan(&one); err == nil {
		t.Fatalf("ip4log write was not rate-limited")
	}

	// Disabled toggle: nothing is written.
	pfAcct.UpdateIplogWithAccounting = false
	pfAcct.Ip4logCache.Flush()
	pfAcct.updateIp4log(ctx, m, ip2)
	if err := pfAcct.Db.QueryRow("SELECT 1 FROM ip4log WHERE ip = ?", ip2).Scan(&one); err == nil {
		t.Fatalf("ip4log written while update_iplog_with_accounting is disabled")
	}
}
