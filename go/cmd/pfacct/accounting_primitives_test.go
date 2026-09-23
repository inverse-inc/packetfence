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

	// No node row yet: the UPDATE matches nothing, which is not an error. It
	// must not be claimed to the AAA layer, and above all must not cache the
	// MAC -- that would suppress last_seen for a whole TTL for a node that is
	// registered a moment later, as it is here.
	if pfAcct.updateNodeLastSeen(ctx, m) {
		t.Error("last_seen claimed as handled for a MAC with no node row")
	}

	if _, err := pfAcct.Db.Exec("INSERT INTO node (mac, status, last_seen) VALUES (?, 'unreg', DATE_SUB(NOW(), INTERVAL 1 DAY))", m.String()); err != nil {
		t.Fatalf("%s", err.Error())
	}

	if !pfAcct.updateNodeLastSeen(ctx, m) {
		t.Error("last_seen not claimed as handled after the node row was created")
	}

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
	if !pfAcct.updateNodeLastSeen(ctx, m) {
		t.Error("a MAC written within the TTL must still be claimed as handled, or httpd.aaa writes it again")
	}
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
	if !pfAcct.updateIp4log(ctx, m, ip1) {
		t.Error("ip4log not claimed as handled after a successful open")
	}

	var one int
	if err := pfAcct.Db.QueryRow("SELECT 1 FROM node WHERE mac = ?", m.String()).Scan(&one); err != nil {
		t.Fatalf("node was not auto-created: %s", err.Error())
	}
	if err := pfAcct.Db.QueryRow("SELECT 1 FROM ip4log WHERE ip = ? AND mac = ? AND end_time = '0000-00-00 00:00:00'", ip1, m.String()).Scan(&one); err != nil {
		t.Fatalf("ip4log entry for %s was not opened: %s", ip1, err.Error())
	}

	// IP change: the old entry closes, the new one opens.
	if !pfAcct.updateIp4log(ctx, m, ip2) {
		t.Error("ip4log not claimed as handled after a successful move")
	}

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
	if !pfAcct.updateIp4log(ctx, m, ip2) {
		t.Error("a MAC/IP pair written within the TTL must still be claimed as handled")
	}
	if err := pfAcct.Db.QueryRow("SELECT 1 FROM ip4log WHERE ip = ?", ip2).Scan(&one); err == nil {
		t.Fatalf("ip4log write was not rate-limited")
	}

	// An address pf::ip4log::open would reject: Perl still resolves and closes
	// the previous entry before rejecting it, so pfacct must decline the whole
	// primitive rather than drop that close silently.
	pfAcct.Ip4logCache.Flush()
	if pfAcct.updateIp4log(ctx, m, "0.0.0.0") {
		t.Error("ip4log claimed as handled for a 0.0.0.0 Framed-IP-Address")
	}

	// pfdhcp.mac2ip_lookup changes where update_ip4log reads the previous IP
	// from, and pfacct only has the SQL half: it must write nothing and claim
	// nothing so httpd.aaa keeps doing it.
	pfAcct.Mac2ipLookup = true
	pfAcct.Ip4logCache.Flush()
	if _, err := pfAcct.Db.Exec("DELETE FROM ip4log WHERE ip = ?", ip1); err != nil {
		t.Fatalf("%s", err.Error())
	}
	if pfAcct.updateIp4log(ctx, m, ip1) {
		t.Error("ip4log claimed as handled while pfdhcp.mac2ip_lookup is enabled")
	}
	if err := pfAcct.Db.QueryRow("SELECT 1 FROM ip4log WHERE ip = ?", ip1).Scan(&one); err == nil {
		t.Fatalf("ip4log written while pfdhcp.mac2ip_lookup is enabled")
	}
	pfAcct.Mac2ipLookup = false

	// Disabled toggle: nothing is written.
	pfAcct.UpdateIplogWithAccounting = false
	pfAcct.Ip4logCache.Flush()
	if pfAcct.updateIp4log(ctx, m, ip2) {
		t.Error("ip4log claimed as handled while update_iplog_with_accounting is disabled")
	}
	if err := pfAcct.Db.QueryRow("SELECT 1 FROM ip4log WHERE ip = ?", ip2).Scan(&one); err == nil {
		t.Fatalf("ip4log written while update_iplog_with_accounting is disabled")
	}
}

func TestNativePrimitivesHeader(t *testing.T) {
	// The AAA layer skips exactly what this header claims, so a primitive that
	// pfacct did not perform for this packet must be absent from it: otherwise
	// both sides skip the write and the packet is lost.
	if got := (nativePrimitives{}).header(); got != "" {
		t.Errorf("header with nothing handled = %q, want the empty string", got)
	}

	if got := (nativePrimitives{nodeLastSeen: true}).header(); got != "node_last_seen" {
		t.Errorf("header with only last_seen handled = %q", got)
	}

	if got := (nativePrimitives{ip4log: true}).header(); got != "ip4log" {
		t.Errorf("header with only ip4log handled = %q", got)
	}

	if got := (nativePrimitives{nodeLastSeen: true, ip4log: true}).header(); got != "node_last_seen,ip4log" {
		t.Errorf("header with both handled = %q", got)
	}
}
