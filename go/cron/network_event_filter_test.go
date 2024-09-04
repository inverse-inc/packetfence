package maint

import (
	"context"
	"net/netip"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/inverse-inc/packetfence/go/db"
)

func TestNetworkEventSql(t *testing.T) {

	mac, err := NewNode("reg")
	if err != nil {
		t.Fatalf("Cannot create new node: %s", err.Error())
	}
	ip := netip.AddrFrom4([4]byte{1, 2, 3, 2})
	sqlStr, bindings := macAndIpsToSql(
		[]string{mac},
		[]netip.Addr{ip},
	)

	want := `
SELECT
    mac,
    (SELECT ip FROM ip4log AS ip WHERE ip.mac = node.mac ORDER BY start_time LIMIT 1) AS ip
FROM node
WHERE
status = "reg" AND NOT EXISTS ( SELECT 1 FROM node_meta where name = 'gc_agent' AND node.mac = node_meta.mac )
AND (
    mac IN (?) OR mac IN (SELECT mac FROM ip4log WHERE ip IN (?))
)
`
	if diff := cmp.Diff(want, sqlStr); diff != "" {
		t.Fatalf("macAndIpsToSql() sql mismatch (-want +got):\n%s", diff)
	}

	if diff := cmp.Diff([]interface{}{mac, ip.String()}, bindings); diff != "" {
		t.Fatalf("macAndIpsToSql() mismatch (-want +got):\n%s", diff)
	}

	database, err := db.DbFromConfig(context.Background())
	if err != nil {
		t.Fatalf("Database: %s", err.Error())
	}

	filter, err := networkEventFilterFromSql(database, sqlStr, bindings)
	if err != nil {
		t.Fatalf("buildNetworkFilter: %s", err.Error())
	}

	testFilter := NewNetworkEventFilter()
	testFilter.AddMac(mac)
	if diff := cmp.Diff(testFilter, filter); diff != "" {
		t.Fatalf("networkEventFilterFromSql() mismatch (-want +got):\n%s", diff)
	}

}
