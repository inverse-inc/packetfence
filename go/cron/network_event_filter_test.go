package maint

import (
	"context"
	"net/netip"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
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
    node.mac AS mac,
    (SELECT GROUP_CONCAT(l.ip) FROM ip4log AS l WHERE l.mac = node.mac AND (l.end_time = '0000-00-00 00:00:00' OR l.end_time > NOW() OR l.start_time = (SELECT MAX(r.start_time) FROM ip4log AS r WHERE r.mac = l.mac))) AS ips
FROM node
WHERE
status = "reg" AND NOT EXISTS ( SELECT 1 FROM node_meta where name = 'gc_agent' AND node.mac = node_meta.mac )
AND (
    node.mac IN (?) OR node.mac IN (SELECT l.mac FROM ip4log AS l WHERE l.ip IN (?) AND (l.end_time = '0000-00-00 00:00:00' OR l.end_time > NOW() OR l.start_time = (SELECT MAX(r.start_time) FROM ip4log AS r WHERE r.mac = l.mac)))
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

func TestNetworkEventSqlMultipleIpsAndMacs(t *testing.T) {
	database, err := getDb()
	if err != nil {
		t.Fatalf("Database: %s", err.Error())
	}

	// The filter is checked against an exact set, so the nodes and their leases
	// have to be known rather than taken from whatever is in the database
	macs := []string{
		"02:99:00:00:00:01",
		"02:99:00:00:00:02",
		"02:99:00:00:00:03",
		"02:99:00:00:00:04",
		"02:99:00:00:00:05",
	}

	for _, mac := range macs {
		if _, err := database.Exec("DELETE FROM ip4log WHERE mac = ?", mac); err != nil {
			t.Fatalf("Cannot cleanup ip4log: %s", err.Error())
		}

		if _, err := database.Exec("DELETE FROM node WHERE mac = ?", mac); err != nil {
			t.Fatalf("Cannot cleanup node: %s", err.Error())
		}

		_, err := database.Exec(`INSERT INTO node (mac, status) VALUES (?, 'reg')`, mac)
		if err != nil {
			t.Fatalf("Cannot insert node: %s", err.Error())
		}
	}

	// macs[0] holds two current leases, macs[1] one, macs[2] a superseded lease
	// on top of its current one, macs[3] two expired ones, and macs[4] an open
	// lease plus a newer one that was closed, making its last known ip expired.
	const current = `'0000-00-00 00:00:00'`
	leases := []struct {
		mac       string
		ip        string
		startTime string
		endTime   string
	}{
		{macs[0], "10.99.0.1", "DATE_SUB(NOW(), INTERVAL 2 HOUR)", current},
		{macs[0], "10.99.0.2", "DATE_SUB(NOW(), INTERVAL 1 HOUR)", current},
		{macs[1], "10.99.0.3", "NOW()", current},
		{macs[2], "10.99.0.4", "DATE_SUB(NOW(), INTERVAL 2 DAY)", "DATE_SUB(NOW(), INTERVAL 1 DAY)"},
		{macs[2], "10.99.0.5", "NOW()", current},
		{macs[3], "10.99.0.6", "DATE_SUB(NOW(), INTERVAL 3 DAY)", "DATE_SUB(NOW(), INTERVAL 2 DAY)"},
		{macs[3], "10.99.0.7", "DATE_SUB(NOW(), INTERVAL 2 DAY)", "DATE_SUB(NOW(), INTERVAL 1 DAY)"},
		{macs[4], "10.99.0.8", "DATE_SUB(NOW(), INTERVAL 3 HOUR)", current},
		{macs[4], "10.99.0.9", "DATE_SUB(NOW(), INTERVAL 1 HOUR)", "DATE_SUB(NOW(), INTERVAL 30 MINUTE)"},
	}

	for _, l := range leases {
		if _, err := database.Exec("DELETE FROM ip4log WHERE ip = ?", l.ip); err != nil {
			t.Fatalf("Cannot cleanup ip4log: %s", err.Error())
		}

		_, err := database.Exec(
			"INSERT INTO ip4log (mac, ip, start_time, end_time) VALUES (?, ?, "+l.startTime+", "+l.endTime+")",
			l.mac, l.ip,
		)
		if err != nil {
			t.Fatalf("Cannot insert into ip4log: %s", err.Error())
		}
	}

	t.Cleanup(func() {
		for _, l := range leases {
			database.Exec("DELETE FROM ip4log WHERE ip = ?", l.ip)
		}

		for _, mac := range macs {
			database.Exec("DELETE FROM node WHERE mac = ?", mac)
		}
	})

	// macs[0] is matched by mac and macs[1] by its current ip. macs[4] is matched
	// by the expired ip it last held, while the ips macs[2] and macs[3] are
	// looked up by were both superseded, so neither of them matches.
	lookupIps := []netip.Addr{
		netip.MustParseAddr("10.99.0.3"),
		netip.MustParseAddr("10.99.0.4"),
		netip.MustParseAddr("10.99.0.6"),
		netip.MustParseAddr("10.99.0.9"),
	}
	sqlStr, bindings := macAndIpsToSql([]string{macs[0]}, lookupIps)

	filter, err := networkEventFilterFromSql(database, sqlStr, bindings)
	if err != nil {
		t.Fatalf("networkEventFilterFromSql: %s", err.Error())
	}

	want := NewNetworkEventFilter()
	want.AddMac(macs[0])
	want.AddMac(macs[1])
	want.AddMac(macs[4])
	// Every ip of a matched node must be in the filter, not only one
	want.AddIp(netip.MustParseAddr("10.99.0.1"))
	want.AddIp(netip.MustParseAddr("10.99.0.2"))
	want.AddIp(netip.MustParseAddr("10.99.0.3"))
	// macs[4] keeps its open lease and the last known one it has since closed
	want.AddIp(netip.MustParseAddr("10.99.0.8"))
	want.AddIp(netip.MustParseAddr("10.99.0.9"))

	if diff := cmp.Diff(want, filter); diff != "" {
		t.Fatalf("networkEventFilterFromSql() mismatch (-want +got):\n%s", diff)
	}

	// One bind per query must give the same answer as a single query
	chunked, err := networkEventFilterFromMacsAndIps(database, []string{macs[0]}, lookupIps, 1)
	if err != nil {
		t.Fatalf("networkEventFilterFromMacsAndIps: %s", err.Error())
	}

	if diff := cmp.Diff(want, chunked); diff != "" {
		t.Fatalf("networkEventFilterFromMacsAndIps() mismatch (-want +got):\n%s", diff)
	}
}

func TestChunkMacsAndIps(t *testing.T) {
	macs := []string{"00:00:00:00:00:01", "00:00:00:00:00:02", "00:00:00:00:00:03"}
	ips := []netip.Addr{
		netip.MustParseAddr("10.99.0.1"),
		netip.MustParseAddr("10.99.0.2"),
	}

	tests := []struct {
		name      string
		macs      []string
		ips       []netip.Addr
		chunkSize int
		want      []macAndIpChunk
	}{
		{
			name: "nothing to look up",
			want: []macAndIpChunk{},
		},
		{
			name:      "everything fits in one chunk",
			macs:      macs,
			ips:       ips,
			chunkSize: 5,
			want:      []macAndIpChunk{{macs: macs, ips: ips}},
		},
		{
			name:      "a chunk is filled with macs before ips",
			macs:      macs,
			ips:       ips,
			chunkSize: 2,
			want: []macAndIpChunk{
				{macs: macs[:2]},
				{macs: macs[2:], ips: ips[:1]},
				{ips: ips[1:]},
			},
		},
		{
			name:      "macs only",
			macs:      macs,
			chunkSize: 2,
			want: []macAndIpChunk{
				{macs: macs[:2]},
				{macs: macs[2:]},
			},
		},
		{
			name:      "ips only",
			ips:       ips,
			chunkSize: 1,
			want: []macAndIpChunk{
				{ips: ips[:1]},
				{ips: ips[1:]},
			},
		},
		{
			name:      "an unusable chunk size still makes progress",
			macs:      macs[:1],
			ips:       ips[:1],
			chunkSize: 0,
			want: []macAndIpChunk{
				{macs: macs[:1]},
				{ips: ips[:1]},
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got := chunkMacsAndIps(test.macs, test.ips, test.chunkSize)
			for _, chunk := range got {
				if len(chunk.macs)+len(chunk.ips) > max(test.chunkSize, 1) {
					t.Fatalf("chunkMacsAndIps() returned a chunk over the chunk size: %v", chunk)
				}
			}

			// netip.Addr has unexported fields, compare it with ==
			opts := cmp.Options{
				cmp.AllowUnexported(macAndIpChunk{}),
				cmpopts.EquateComparable(netip.Addr{}),
				cmpopts.EquateEmpty(),
			}
			if diff := cmp.Diff(test.want, got, opts); diff != "" {
				t.Fatalf("chunkMacsAndIps() mismatch (-want +got):\n%s", diff)
			}
		})
	}
}
