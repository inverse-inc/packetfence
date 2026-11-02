package maint

import (
	"context"
	"database/sql"
	"net/netip"
	"strings"

	"github.com/inverse-inc/go-utils/log"
)

type NetworkEventFilter struct {
	MacSet Set[string]
	IpSet  Set[netip.Addr]
}

func NewNetworkEventFilter() NetworkEventFilter {
	return NetworkEventFilter{
		MacSet: make(Set[string]),
		IpSet:  make(Set[netip.Addr]),
	}
}

func (f *NetworkEventFilter) Count() int {
	return len(f.IpSet) + len(f.MacSet)
}

func (f *NetworkEventFilter) Filter(n *NetworkEvent) bool {
	if f.IpSet.Contains(n.SourceIp) || f.IpSet.Contains(n.DestIp) {
		return true
	}

	if n.DestInventoryitem != nil {
		for _, i := range n.DestInventoryitem.ExternalIDS {
			if f.MacSet.Contains(i) {
				return true
			}
		}
	}

	if n.SourceInventoryItem != nil {
		for _, i := range n.SourceInventoryItem.ExternalIDS {
			if f.MacSet.Contains(i) {
				return true
			}
		}
	}

	return false
}

func (f *NetworkEventFilter) FilterEvents(events []*NetworkEvent) []*NetworkEvent {
	filtered := make([]*NetworkEvent, 0, len(events))
	for _, e := range events {
		if f.Filter(e) {
			filtered = append(filtered, e)
		}
	}

	return filtered
}

func networkEventFilterFromSql(dbh *sql.DB, sqlStr string, bindings []interface{}) (NetworkEventFilter, error) {
	filter := NewNetworkEventFilter()
	err := filter.addFromSql(dbh, sqlStr, bindings)
	return filter, err
}

func (f *NetworkEventFilter) addFromSql(dbh *sql.DB, sqlStr string, bindings []interface{}) error {
	rows, err := dbh.Query(sqlStr, bindings...)
	if err != nil {
		return err
	}

	defer rows.Close()
	for rows.Next() {
		mac := ""
		var ips sql.NullString
		err := rows.Scan(&mac, &ips)
		if err != nil {
			return err
		}

		f.AddMac(mac)
		if !ips.Valid {
			continue
		}

		for _, ip := range strings.Split(ips.String, ",") {
			ip2, err := netip.ParseAddr(ip)
			if err != nil {
				log.LogError(context.Background(), "Error Parsing Addr: "+err.Error())
			} else {
				f.AddIp(ip2)
			}
		}
	}

	return rows.Err()
}

func (f *NetworkEventFilter) AddMac(mac string) {
	f.MacSet.AddIf(mac, func(e string) bool { return e != "" && e != "00:00:00:00:00:00" })
}

func (f *NetworkEventFilter) AddMacs(macs []string) {
	for _, mac := range macs {
		f.AddMac(mac)
	}
}

func (f *NetworkEventFilter) AddIps(ips []netip.Addr) {
	for _, ip := range ips {
		f.AddIp(ip)
	}
}

func (f *NetworkEventFilter) AddIp(ip netip.Addr) {
	f.IpSet.AddIf(ip, func(e netip.Addr) bool { return e.IsValid() })
}

func (f *NetworkEventFilter) Macs() []string {
	return f.MacSet.Members()
}

func (f *NetworkEventFilter) Ips() []netip.Addr {
	return f.IpSet.Members()
}

// maxBindsPerQuery caps how many placeholders a single lookup uses. A submit
// batch covers a whole aggregation window, so it can hold more macs and ips
// than the 65535 placeholders a prepared statement allows.
const maxBindsPerQuery = 4096

func GetFilterFromNetworkEvents(db *sql.DB, events []*NetworkEvent) (NetworkEventFilter, error) {
	lookup := buildNetworkEventFilter(events)
	return networkEventFilterFromMacsAndIps(db, lookup.Macs(), lookup.Ips(), maxBindsPerQuery)
}

// networkEventFilterFromMacsAndIps looks the macs and ips up in chunks of at
// most chunkSize binds. Every chunk returns all the ips of the nodes it
// matches, so the union of the chunks is what a single query would have
// returned.
func networkEventFilterFromMacsAndIps(db *sql.DB, macs []string, ips []netip.Addr, chunkSize int) (NetworkEventFilter, error) {
	filter := NewNetworkEventFilter()
	for _, chunk := range chunkMacsAndIps(macs, ips, chunkSize) {
		sqlStr, bindings := macAndIpsToSql(chunk.macs, chunk.ips)
		if err := filter.addFromSql(db, sqlStr, bindings); err != nil {
			return filter, err
		}
	}

	return filter, nil
}

type macAndIpChunk struct {
	macs []string
	ips  []netip.Addr
}

func chunkMacsAndIps(macs []string, ips []netip.Addr, chunkSize int) []macAndIpChunk {
	// A chunk must hold at least one bind, otherwise the loop below never
	// consumes anything
	chunkSize = max(chunkSize, 1)
	chunks := []macAndIpChunk{}
	for len(macs) > 0 || len(ips) > 0 {
		chunk := macAndIpChunk{}
		count := min(len(macs), chunkSize)
		chunk.macs, macs = macs[:count], macs[count:]
		count = min(len(ips), chunkSize-count)
		chunk.ips, ips = ips[:count], ips[count:]
		chunks = append(chunks, chunk)
	}

	return chunks
}

func buildNetworkEventFilter(events []*NetworkEvent) NetworkEventFilter {
	filter := NewNetworkEventFilter()
	for _, e := range events {
		if e.DestInventoryitem != nil {
			filter.AddMacs(e.DestInventoryitem.ExternalIDS)
		}

		if e.SourceInventoryItem != nil {
			filter.AddMacs(e.SourceInventoryItem.ExternalIDS)
		}

		filter.AddIp(e.SourceIp)
		filter.AddIp(e.DestIp)
	}

	return filter
}

// nodeHoldsIp tells the ip4log rows that still stand for a node apart from the
// ones it has moved on from: an open lease, and the last ip it is known to have
// held once that lease has expired. The ips a node contributes and the ips it
// is matched on are the same set, so a node is never matched through an ip it
// no longer answers to. The filter is an allowlist, hence keeping the last
// known ip: forwarding an event for an ip a node has only just stopped using is
// cheaper than dropping a real one.
const nodeHoldsIp = `(l.end_time = '0000-00-00 00:00:00' OR l.end_time > NOW() OR l.start_time = (SELECT MAX(r.start_time) FROM ip4log AS r WHERE r.mac = l.mac))`

func macAndIpsToSql(macs []string, ips []netip.Addr) (string, []interface{}) {
	binds := make([]interface{}, 0, len(macs)+len(ips))
	parts := []string{}
	sql := `
SELECT
    node.mac AS mac,
    (SELECT GROUP_CONCAT(l.ip) FROM ip4log AS l WHERE l.mac = node.mac AND ` + nodeHoldsIp + `) AS ips
FROM node
WHERE
status = "reg" AND NOT EXISTS ( SELECT 1 FROM node_meta where name = 'gc_agent' AND node.mac = node_meta.mac )
AND (`

	if len(macs) > 0 {
		parts = append(parts, "node.mac IN (?"+strings.Repeat(", ?", len(macs)-1)+")")
		for _, m := range macs {
			binds = append(binds, m)
		}
	}

	if len(ips) > 0 {
		parts = append(parts, "node.mac IN (SELECT l.mac FROM ip4log AS l WHERE l.ip IN (?"+strings.Repeat(", ?", len(ips)-1)+") AND "+nodeHoldsIp+")")
		for _, m := range ips {
			binds = append(binds, m.String())
		}
	}

	sql += "\n    " + strings.Join(parts, " OR ") + "\n)\n"

	return sql, binds
}
