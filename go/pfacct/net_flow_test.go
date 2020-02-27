package main

import (
	"testing"
	"time"
)

func TestNetFlowBandwidthAccountingRecToSQLSelect(t *testing.T) {
	rec := NetFlowBandwidthAccountingRec{
		Ip:         "1.2.3.4",
		TimeBucket: time.Date(2009, time.November, 10, 23, 0, 0, 0, time.UTC),
		InBytes:    1000,
		OutBytes:   1000,
	}

	expectedSQL := `SELECT _latin1"1.2.3.4" as ip, 1000 as in_bytes_, 1000 as out_bytes_, "2009-11-10 23:00:00" as time_bucket
`
	sql := rec.ToSQLSelect()
	if sql != expectedSQL {
		t.Errorf("Error:\nExpected '%s'\nGot      '%s'", expectedSQL, sql)
	}
}

func TestNetFlowBandwidthAccountingRecsToSQLSelect(t *testing.T) {
	recs := NetFlowBandwidthAccountingRecs{
		NetFlowBandwidthAccountingRec{
			Ip:         "1.2.3.4",
			TimeBucket: time.Date(2009, time.November, 10, 23, 0, 0, 0, time.UTC),
			InBytes:    1000,
			OutBytes:   1000,
		},
		NetFlowBandwidthAccountingRec{
			Ip:         "1.2.3.5",
			TimeBucket: time.Date(2009, time.November, 10, 23, 0, 0, 0, time.UTC),
			InBytes:    1000,
			OutBytes:   1000,
		},
		NetFlowBandwidthAccountingRec{
			Ip:         "1.2.3.6",
			TimeBucket: time.Date(2009, time.November, 10, 23, 0, 0, 0, time.UTC),
			InBytes:    1000,
			OutBytes:   1000,
		},
	}

	expectedSQL := `INSERT INTO bandwidth_accounting (tenant_id, mac, time_bucket, in_bytes, out_bytes)
    SELECT * FROM (
        SELECT time_bucket, tenant_id, mac, in_bytes_, out_bytes_ FROM (
            SELECT _latin1"1.2.3.4" as ip, 1000 as in_bytes_, 1000 as out_bytes_, "2009-11-10 23:00:00" as time_bucket
            UNION ALL SELECT _latin1"1.2.3.5" as ip, 1000 as in_bytes_, 1000 as out_bytes_, "2009-11-10 23:00:00" as time_bucket
            UNION ALL SELECT _latin1"1.2.3.6" as ip, 1000 as in_bytes_, 1000 as out_bytes_, "2009-11-10 23:00:00" as time_bucket
        ) as time_buckets INNER JOIN ip4log as ip4 ON time_buckets.ip = ip4.ip
    ) as x
ON DUPLICATE KEY UPDATE in_bytes = in_bytes + VALUES(in_bytes), out_bytes = out_bytes + VALUES(out_bytes);`
	sql := recs.ToSQL()
	if sql != expectedSQL {
		t.Errorf("Error:\nExpected:\n%s\nGot:\n%s\n", expectedSQL, sql)
	}
}
