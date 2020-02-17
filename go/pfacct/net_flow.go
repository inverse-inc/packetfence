package main

import (
	"context"
	"database/sql"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/netflow5"
	"strconv"
	"time"
)

const (
	MySqlDateFormat = "2006-01-02 15:04:05"
)

type NetFlowBandwidthAccountingRec struct {
	Ip         string
	TimeBucket time.Time
	InBytes    uint64
	OutBytes   uint64
}

func (rec *NetFlowBandwidthAccountingRec) ToSQLSelect() string {
	buffer := [256]byte{}
	sqlBytes := buffer[:0] // Use buffer as the backing of the slice
	sqlBytes = append(sqlBytes, []byte(`SELECT "`)...)
	sqlBytes = append(sqlBytes, []byte(rec.Ip)...)
	sqlBytes = append(sqlBytes, []byte(`" as ip, `)...)
	sqlBytes = strconv.AppendUint(sqlBytes, rec.InBytes, 10)
	sqlBytes = append(sqlBytes, []byte(` as in_bytes_, `)...)
	sqlBytes = strconv.AppendUint(sqlBytes, rec.OutBytes, 10)
	sqlBytes = append(sqlBytes, []byte(` as out_bytes_, "`)...)
	sqlBytes = rec.TimeBucket.AppendFormat(sqlBytes, MySqlDateFormat)
	sqlBytes = append(sqlBytes, []byte(`" as time_bucket`)...)
	return string(sqlBytes)
}

type NetFlowBandwidthAccountingRecs []NetFlowBandwidthAccountingRec

func (array *NetFlowBandwidthAccountingRecs) AppendEmpty() {
	*array = append(*array, NetFlowBandwidthAccountingRec{})
}

/*
INSERT INTO bandwidth_accounting (tenant_id, mac, time_bucket, in_bytes, out_bytes)
    SELECT * FROM (
        SELECT time_bucket, tenant_id, mac, in_bytes_, out_bytes_ FROM  (
            SELECT
                "1.2.3.4" as ip , 2 as in_bytes_, 3 as out_bytes_, '1975-06-11 23:50:00' as time_bucket
            UNION ALL SELECT
                "1.2.3.5" as ip , 2 as in_bytes_, 3 as out_bytes_, '1975-06-11 23:50:00' as time_bucket
        ) as time_buckets INNER JOIN ip4log as ip4 ON time_buckets.ip = ip4.ip
    ) as x
ON DUPLICATE KEY UPDATE in_bytes = in_bytes + VALUES(in_bytes), out_bytes = out_bytes + VALUES(out_bytes);
*/

func (array NetFlowBandwidthAccountingRecs) ToSQL() string {
	if len(array) == 0 {
		return ""
	}

	sql :=
		`INSERT INTO bandwidth_accounting (tenant_id, mac, time_bucket, in_bytes, out_bytes) 
    SELECT * FROM ( 
        SELECT time_bucket, tenant_id, mac, in_bytes_, out_bytes_ FROM  (`
	first := array[0]
	sql += first.ToSQLSelect()
	for _, rec := range array[1:] {
		sql += " UNION ALL " + rec.ToSQLSelect()
	}

	sql += `
        ) as time_buckets INNER JOIN ip4log as ip4 ON time_buckets.ip = ip4.ip 
    ) as x
ON DUPLICATE KEY UPDATE in_bytes = in_bytes + VALUES(in_bytes), out_bytes = out_bytes + VALUES(out_bytes);`

	return sql
}

func IpAddressAllowed(ip string) bool {
	return true
}

type BandwidthAccountingNetFlow struct {
	Db *sql.DB
}

func NewBandwidthAccountingNetFlow() *BandwidthAccountingNetFlow {
	var ctx = context.Background()
	db, err := db.DbFromConfig(ctx)
	if err != nil {
		return nil
	}

	return &BandwidthAccountingNetFlow{Db: db}
}

func (h *BandwidthAccountingNetFlow) HandleFlows(header *netflow5.Header, flows []netflow5.Flow) {
	recs := NetFlowV5ToBandwidthAccounting(header, flows)
	sql := recs.ToSQL()
	if sql != "" {
		h.Db.Exec(sql)
	}
}

func NetFlowV5ToBandwidthAccounting(header *netflow5.Header, flows []netflow5.Flow) NetFlowBandwidthAccountingRecs {
	recs := NetFlowBandwidthAccountingRecs{}
	lookup := map[string]int{}
	index := 0
	srcIndex := 0
	dstIndex := 0
	unixTime := time.Unix(int64(header.UnixSecs()), int64(header.UnixNsecs()))
	for _, flow := range flows {
		srcIndex = -1
		dstIndex = -1
		var found bool
		srcIp := flow.SrcIP().String()
		if IpAddressAllowed(srcIp) {
			if srcIndex, found = lookup[srcIp]; !found {
				recs.AppendEmpty()
				lookup[srcIp] = index
				srcIndex = index
				index++
			}
		}
		dstIp := flow.DstIP().String()
		if IpAddressAllowed(dstIp) {
			if dstIndex, found = lookup[dstIp]; !found {
				recs.AppendEmpty()
				lookup[dstIp] = index
				dstIndex = index
				index++
			}
		}

		layer3Bytes := uint64(flow.DPkts())
		if srcIndex != -1 {
			recs[srcIndex].Ip = srcIp
			recs[srcIndex].TimeBucket = unixTime
			recs[srcIndex].InBytes = 0
			recs[srcIndex].OutBytes += layer3Bytes
		}

		if dstIndex != -1 {
			recs[dstIndex].Ip = dstIp
			recs[dstIndex].TimeBucket = unixTime
			recs[dstIndex].InBytes += layer3Bytes
			recs[dstIndex].OutBytes = 0
		}

	}
	return recs
}

func HandleNetFlowV5(header *netflow5.Header, flows []netflow5.Flow) {
	recs := NetFlowV5ToBandwidthAccounting(header, flows)
	sql := recs.ToSQL()
	_ = sql
}
