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
	rows, err := dbh.Query(sqlStr, bindings...)
	if err != nil {
		return filter, err
	}

	for rows.Next() {
		mac := ""
		var ip sql.NullString
		err := rows.Scan(&mac, &ip)
		if err != nil {
			return filter, err
		}

		filter.AddMac(mac)
		if ip.Valid {
			ip2, err := netip.ParseAddr(ip.String)
			if err != nil {
				log.LogError(context.Background(), "Error Parsing Addr: "+err.Error())
			} else {
				filter.AddIp(ip2)
			}
		}
	}
	return filter, nil
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

func GetFilterFromNetworkEvents(db *sql.DB, events []*NetworkEvent) (NetworkEventFilter, error) {
	sqlStr, bindings := networkEventsToSQL(events)
	if bindings == nil {
		return NewNetworkEventFilter(), nil
	}

	return networkEventFilterFromSql(db, sqlStr, bindings)
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

func networkEventsToSQL(events []*NetworkEvent) (string, []interface{}) {
	filter := buildNetworkEventFilter(events)
	if filter.Count() == 0 {
		return "", nil
	}

	return macAndIpsToSql(filter.Macs(), filter.Ips())
}

func macAndIpsToSql(macs []string, ips []netip.Addr) (string, []interface{}) {
	binds := make([]interface{}, 0, len(macs)+len(ips))
	parts := []string{}
	sql := `
SELECT
    mac,
    (SELECT ip FROM ip4log AS ip WHERE ip.mac = node.mac ORDER BY start_time LIMIT 1) AS ip
FROM node
WHERE
status = "reg" AND NOT EXISTS ( SELECT 1 FROM node_meta where name = 'gc_agent' AND node.mac = node_meta.mac )
AND (`

	if len(macs) > 0 {
		parts = append(parts, "mac IN (?"+strings.Repeat(", ?", len(macs)-1)+")")
		for _, m := range macs {
			binds = append(binds, m)
		}
	}

	if len(ips) > 0 {
		parts = append(parts, "mac IN (SELECT mac FROM ip4log WHERE ip IN (?"+strings.Repeat(", ?", len(ips)-1)+"))")
		for _, m := range ips {
			binds = append(binds, m.String())
		}
	}

	sql += "\n    " + strings.Join(parts, " OR ") + "\n)\n"

	return sql, binds
}
