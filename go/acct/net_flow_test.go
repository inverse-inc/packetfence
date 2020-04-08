package main

import (
	"testing"
	"time"
)

func TestNetFlowBandwidthAccountingRecToSQLSelect(t *testing.T) {
	rec := NetFlowBandwidthAccountingRec{
		Ip:            "1.2.3.4",
		UniqueSession: (0xFFFFFFFF << 32) | (0x01020304),
		TimeBucket:    time.Date(2009, time.November, 10, 23, 0, 0, 0, time.UTC),
		InBytes:       1000,
		OutBytes:      1000,
	}

	expectedSQL := `SELECT _latin1"1.2.3.4" as ip, 18446744069431493380 as unique_session_id, 1000 as in_bytes_, 1000 as out_bytes_, "2009-11-10 23:00:00" as time_bucket
`
	sql := rec.ToSQLSelect()
	if sql != expectedSQL {
		t.Errorf("Error:\nExpected '%s'\nGot      '%s'", expectedSQL, sql)
	}
}

func TestNetFlowBandwidthAccountingRecsToSQLSelect(t *testing.T) {
	recs := NetFlowBandwidthAccountingRecs{
		NetFlowBandwidthAccountingRec{
			Ip:            "1.2.3.4",
			UniqueSession: (0xFFFFFFFF << 32) | (0x01020304),
			TimeBucket:    time.Date(2009, time.November, 10, 23, 0, 0, 0, time.UTC),
			InBytes:       1000,
			OutBytes:      1000,
		},
		NetFlowBandwidthAccountingRec{
			Ip:            "1.2.3.5",
			UniqueSession: (0xFFFFFFFF << 32) | (0x01020305),
			TimeBucket:    time.Date(2009, time.November, 10, 23, 0, 0, 0, time.UTC),
			InBytes:       1000,
			OutBytes:      1000,
		},
		NetFlowBandwidthAccountingRec{
			Ip:            "1.2.3.6",
			UniqueSession: (0xFFFFFFFF << 32) | (0x01020306),
			TimeBucket:    time.Date(2009, time.November, 10, 23, 0, 0, 0, time.UTC),
			InBytes:       1000,
			OutBytes:      1000,
		},
	}

	expectedSQL := `INSERT INTO bandwidth_accounting (node_id, tenant_id, mac, unique_session_id, time_bucket, in_bytes, out_bytes, source_type)
    SELECT * FROM (
        SELECT ((tenant_id << 48) | CAST(CONV(REPLACE(mac,":",""), 16, 10) AS UNSIGNED)) as node_id, tenant_id, mac, unique_session_id, time_bucket, in_bytes_, out_bytes_, "net_flow" FROM (
            SELECT _latin1"1.2.3.4" as ip, 18446744069431493380 as unique_session_id, 1000 as in_bytes_, 1000 as out_bytes_, "2009-11-10 23:00:00" as time_bucket
            UNION ALL SELECT _latin1"1.2.3.5" as ip, 18446744069431493381 as unique_session_id, 1000 as in_bytes_, 1000 as out_bytes_, "2009-11-10 23:00:00" as time_bucket
            UNION ALL SELECT _latin1"1.2.3.6" as ip, 18446744069431493382 as unique_session_id, 1000 as in_bytes_, 1000 as out_bytes_, "2009-11-10 23:00:00" as time_bucket
        ) as time_buckets INNER JOIN ip4log as ip4 ON time_buckets.ip = ip4.ip
    ) as x
ON DUPLICATE KEY UPDATE in_bytes = in_bytes + VALUES(in_bytes), out_bytes = out_bytes + VALUES(out_bytes), last_updated = NOW();`
	sql := recs.ToSQL()
	if sql != expectedSQL {
		t.Errorf("Error:\nExpected:\n%s\nGot:\n%s\n", expectedSQL, sql)
	}
}
