package main

import (
	"context"
	"net"
	"strconv"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/netflow5"
	"github.com/inverse-inc/packetfence/go/netflow5/processor"
)

const (
	MySqlDateFormat = "2006-01-02 15:04:05"
)

type NetFlowBandwidthAccountingRec struct {
	Ip            string
	UniqueSession uint64
	TimeBucket    time.Time
	InBytes       uint64
	OutBytes      uint64
}

func (rec *NetFlowBandwidthAccountingRec) ToSQLSelect() string {
	buffer := [256]byte{}
	sqlBytes := buffer[:0] // Use buffer as the backing of the slice
	sqlBytes = append(sqlBytes, []byte(`SELECT _latin1"`)...)
	sqlBytes = append(sqlBytes, []byte(rec.Ip)...)
	sqlBytes = append(sqlBytes, []byte(`" as ip, `)...)
	sqlBytes = strconv.AppendUint(sqlBytes, rec.UniqueSession, 10)
	sqlBytes = append(sqlBytes, []byte(` as unique_session_id, `)...)
	sqlBytes = strconv.AppendUint(sqlBytes, rec.InBytes, 10)
	sqlBytes = append(sqlBytes, []byte(` as in_bytes_, `)...)
	sqlBytes = strconv.AppendUint(sqlBytes, rec.OutBytes, 10)
	sqlBytes = append(sqlBytes, []byte(` as out_bytes_, "`)...)
	sqlBytes = rec.TimeBucket.AppendFormat(sqlBytes, MySqlDateFormat)
	sqlBytes = append(sqlBytes, []byte("\" as time_bucket\n")...)
	return string(sqlBytes)
}

type NetFlowBandwidthAccountingRecs []NetFlowBandwidthAccountingRec

func (array *NetFlowBandwidthAccountingRecs) Append(ip net.IP, TimeBucket time.Time) int {
	index := len(*array)
	var unique_session uint64 = (0xFFFFFFFF << 32) | (uint64(ip[0]) << 24) | (uint64(ip[1]) << 16) | (uint64(ip[2]) << 8) | uint64(ip[3])
	*array = append(*array, NetFlowBandwidthAccountingRec{Ip: ip.String(), TimeBucket: TimeBucket, UniqueSession: unique_session})
	return index
}

func (array NetFlowBandwidthAccountingRecs) ToSQL() string {
	if len(array) == 0 {
		return ""
	}

	sql :=
		`INSERT INTO bandwidth_accounting (node_id, tenant_id, mac, unique_session_id, time_bucket, in_bytes, out_bytes, source_type)
    SELECT * FROM (
        SELECT ((tenant_id << 48) | CAST(CONV(REPLACE(mac,":",""), 16, 10) AS UNSIGNED)) as node_id, tenant_id, mac, unique_session_id, time_bucket, in_bytes_, out_bytes_, "net_flow" FROM (
            `
	first := array[0]
	sql += first.ToSQLSelect()
	for _, rec := range array[1:] {
		sql += "            UNION ALL " + rec.ToSQLSelect()
	}

	sql += `        ) as time_buckets INNER JOIN ip4log as ip4 ON time_buckets.ip = ip4.ip
    ) as x
ON DUPLICATE KEY UPDATE in_bytes = in_bytes + VALUES(in_bytes), out_bytes = out_bytes + VALUES(out_bytes), last_updated = NOW();`

	return sql
}

func (h *PfAcct) HandleFlows(header *netflow5.Header, flows []netflow5.Flow) {
	defer h.NewTiming().Send("net_flow.HandleFlows")
	recs := h.NetFlowV5ToBandwidthAccounting(header, flows)
	sql := recs.ToSQL()
	if sql != "" {
		h.Db.Exec(sql)
	}
}

func (h *PfAcct) IpAddressAllowed(ip net.IP) bool {
	if h.AllNetworks {
		return true
	}

	for _, n := range h.AllowedNetworks {
		if n.Contains(ip) {
			return true
		}
	}

	return false
}

func (h *PfAcct) NetFlowV5ToBandwidthAccounting(header *netflow5.Header, flows []netflow5.Flow) NetFlowBandwidthAccountingRecs {
	recs := NetFlowBandwidthAccountingRecs{}
	lookup := map[string]int{}
	srcIndex := 0
	dstIndex := 0
	unixTime := time.Unix(int64(header.UnixSecs()), int64(header.UnixNsecs()))
	unixTime = unixTime.Truncate(h.TimeDuration)
	for _, flow := range flows {
		srcIndex = -1
		dstIndex = -1
		var found bool
		srcIP := flow.SrcIP()
		if h.IpAddressAllowed(srcIP) {
			srcIpStr := srcIP.String()
			if srcIndex, found = lookup[srcIpStr]; !found {
				srcIndex = recs.Append(srcIP, unixTime)
				lookup[srcIpStr] = srcIndex
			}
		}

		dstIP := flow.DstIP()
		if h.IpAddressAllowed(dstIP) {
			dstIpStr := dstIP.String()
			if dstIndex, found = lookup[dstIpStr]; !found {
				dstIndex = recs.Append(dstIP, unixTime)
				lookup[dstIpStr] = dstIndex
			}
		}

		layer3Bytes := uint64(flow.DOctets())
		if srcIndex != -1 {
			recs[srcIndex].OutBytes += layer3Bytes
		}

		if dstIndex != -1 {
			recs[dstIndex].InBytes += layer3Bytes
		}

	}

	return recs
}

func (h *PfAcct) netflowProcessor() (*processor.Processor, error) {
	addr := netFlowAddr + ":" + h.NetFlowPort
	conn, err := net.ListenPacket("udp", addr)
	if err != nil {
		return nil, err
	}

	log.LoggerWContext(context.Background()).Info("Starting listening to netflow at '" + addr + "'")

	return &processor.Processor{
		Handler: h,
		Conn:    conn,
	}, nil
}
