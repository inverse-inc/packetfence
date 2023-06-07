package maint

import (
	"encoding/json"
	"testing"

	"github.com/inverse-inc/packetfence/go/common"
)

const sample = `[{"ip":"1.1.1.1","mac":"11:22:33:44:55:66","qname":"a.a","qtype":"A","scope":"a","answer":"answer"}]`

func TestFlushRadiusAuditLog(t *testing.T) {
	var entries []common.DNSAuditLog = make([]common.DNSAuditLog, 1)
	json.Unmarshal([]byte(sample), &entries)
	job := NewFlushDNSAuditLog(map[string]interface{}{
		"batch":       100.0,
		"type":        "flush_radius_audit_log_job",
		"status":      "enabled",
		"description": "Test",
		"schedule":    "@every 1m",
		"timeout":     10.0,
		"local":       "enabled",
	})

	j := job.(*FlushDNSAuditLog)
	sql, args, err := j.buildQuery(entries)
	if err != nil {
		t.Fatalf("Cannot flush logs %s", err.Error())
	}
	_ = sql
	_ = args

	db, err := getDb()
	if err != nil {
		t.Fatalf("No database %s", err.Error())
	}

	res, err := db.Exec("DELETE FROM dns_audit_log;")
	if err != nil {
		t.Fatalf("Delete from %s", err.Error())
	}
	_ = res

	err = j.flushLogs(entries)
	if err != nil {
		t.Fatalf("Cannot flush logs %s", err.Error())
	}

	row := db.QueryRow("SELECT id FROM dns_audit_log;")
	if err := row.Err(); err != nil {
		t.Fatalf("Delete from %s", err.Error())
	}

	id := 0
	err = row.Scan(&id)
	if err != nil {
		t.Fatalf("Cannot flush logs %s", err.Error())
	}
}
