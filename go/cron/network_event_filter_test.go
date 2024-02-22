package maint

import (
	"context"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/inverse-inc/packetfence/go/db"
)

func TestNetworkEventSql(t *testing.T) {

	mac, err := NewNode("reg")
	if err != nil {
		t.Fatalf("Cannot create new node: %s", err.Error())
	}
	ip := "1.2.3.2"
	sqlStr, bindings := macAndIpsToSql(
		[]string{mac},
		[]string{ip},
	)

	want := `
SELECT
    mac,
    (SELECT ip FROM ip4log AS ip WHERE ip.mac = node.mac) AS ip
FROM node
WHERE status = "reg" AND (
    mac IN (?) OR (SELECT mac FROM ip4log WHERE ip IN (?))
)
`
	if diff := cmp.Diff(want, sqlStr); diff != "" {
		t.Fatalf("macAndIpsToSql() sql mismatch (-want +got):\n%s", diff)
	}

	if diff := cmp.Diff([]interface{}{mac, ip}, bindings); diff != "" {
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
