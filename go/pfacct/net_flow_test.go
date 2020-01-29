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

	expectedSQL := `SELECT "1.2.3.4" as ip, 1000 as in_bytes_, 1000 as out_bytes_, "2009-11-10 23:00:00" as time_bucket`
	sql := rec.ToSQLSelect()
	if sql != expectedSQL {
		t.Errorf("Error:\nExpected '%s'\nGot      '%s'", expectedSQL, sql)
	}
}
