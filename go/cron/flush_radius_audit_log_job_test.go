package maint

import (
	"context"
	"encoding/json"
	"testing"
)

const RADIUS_SAMPLE = `[["Accept",{"User-Name":{"type":"string","value":"a0:00:00:00:00:01"},"User-Password":{"type":"string","value":"******"},"NAS-IP-Address":{"type":"ipaddr","value":"192.168.8.1"},"NAS-Port":{"type":"integer","value":1},"Service-Type":{"type":"integer","value":"Call-Check"},"Called-Station-Id":{"type":"string","value":"03:00:00:00:00:01"},"Calling-Station-Id":{"type":"string","value":"a1:00:00:00:00:01"},"NAS-Port-Type":{"type":"integer","value":"Wireless-802.11"},"Event-Timestamp":{"type":"date","value":"May 24 2023 14:50:28 UTC"},"Stripped-User-Name":{"type":"string","value":"a0:00:00:00:00:01"},"Realm":{"type":"string","value":"null"},"FreeRADIUS-Client-IP-Address":{"type":"ipaddr","value":"172.105.101.170"},"PacketFence-KeyBalanced":{"type":"string","value":"16d01a2b08829d827b5be1abae145f0a"},"PacketFence-Radius-Ip":{"type":"string","value":"172.105.101.170"}},{"REST-HTTP-Status-Code":{"type":"integer","value":200},"Tunnel-Private-Group-Id":{"type":"string","value":"2"},"Tunnel-Medium-Type":{"type":"integer","value":"IEEE-802"},"Tunnel-Type":{"type":"integer","value":"VLAN"}},{"PacketFence-Switch-Id":{"type":"string","value":"192.168.8.1"},"PacketFence-Switch-Mac":{"type":"string","value":"03:00:00:00:00:01"},"PacketFence-Switch-Ip-Address":{"type":"string","value":"192.168.8.1"},"PacketFence-IfIndex":{"type":"string","value":"1"},"PacketFence-Connection-Type":{"type":"string","value":"Wireless-802.11-NoEAP"},"Auth-Type":{"type":"integer","value":"Accept"},"PacketFence-Role":{"type":"string","value":"registration"},"PacketFence-Status":{"type":"string","value":"unreg"},"PacketFence-Profile":{"type":"string","value":"default"},"PacketFence-AutoReg":{"type":"string","value":"0"},"PacketFence-IsPhone":{"type":"string","value":""},"PacketFence-Request-Time":{"type":"integer","value":0}}]]`

const RADIUS_ENTRY = `["Accept",{"User-Name":{"type":"string","value":"a0:00:00:00:00:01"},"User-Password":{"type":"string","value":"******"},"NAS-IP-Address":{"type":"ipaddr","value":"192.168.8.1"},"NAS-Port":{"type":"integer","value":1},"Service-Type":{"type":"integer","value":"Call-Check"},"Called-Station-Id":{"type":"string","value":"03:00:00:00:00:01"},"Calling-Station-Id":{"type":"string","value":"a1:00:00:00:00:01"},"NAS-Port-Type":{"type":"integer","value":"Wireless-802.11"},"Event-Timestamp":{"type":"date","value":"May 24 2023 14:50:28 UTC"},"Stripped-User-Name":{"type":"string","value":"a0:00:00:00:00:01"},"Realm":{"type":"string","value":"null"},"FreeRADIUS-Client-IP-Address":{"type":"ipaddr","value":"172.105.101.170"},"PacketFence-KeyBalanced":{"type":"string","value":"16d01a2b08829d827b5be1abae145f0a"},"PacketFence-Radius-Ip":{"type":"string","value":"172.105.101.170"}},{"REST-HTTP-Status-Code":{"type":"integer","value":200},"Tunnel-Private-Group-Id":{"type":"string","value":"2"},"Tunnel-Medium-Type":{"type":"integer","value":"IEEE-802"},"Tunnel-Type":{"type":"integer","value":"VLAN"}},{"PacketFence-Switch-Id":{"type":"string","value":"192.168.8.1"},"PacketFence-Switch-Mac":{"type":"string","value":"03:00:00:00:00:01"},"PacketFence-Switch-Ip-Address":{"type":"string","value":"192.168.8.1"},"PacketFence-IfIndex":{"type":"string","value":"1"},"PacketFence-Connection-Type":{"type":"string","value":"Wireless-802.11-NoEAP"},"Auth-Type":{"type":"integer","value":"Accept"},"PacketFence-Role":{"type":"string","value":"registration"},"PacketFence-Status":{"type":"string","value":"unreg"},"PacketFence-Profile":{"type":"string","value":"default"},"PacketFence-AutoReg":{"type":"string","value":"0"},"PacketFence-IsPhone":{"type":"string","value":""},"PacketFence-Request-Time":{"type":"integer","value":0}}]`

func TestFlushRadiusAuditLog(t *testing.T) {
	var entries [][]interface{} = make([][]interface{}, 1)
	json.Unmarshal([]byte(RADIUS_SAMPLE), &entries)
	job := NewFlushRadiusAuditLogJob(map[string]interface{}{
		"batch":       100.0,
		"type":        "flush_radius_audit_log_job",
		"status":      "enabled",
		"description": "Test",
		"schedule":    "@every 1m",
		"timeout":     1.0,
		"local":       "enabled",
	})

	j := job.(*FlushRadiusAuditLogJob)
	_, _, err := j.buildQuery(entries)
	if err != nil {
		t.Fatalf("Cannot flush logs %s", err.Error())
	}

	db, err := getDb()
	if err != nil {
		t.Fatalf("No database %s", err.Error())
	}

	res, err := db.Exec("DELETE FROM radius_audit_log;")
	if err != nil {
		t.Fatalf("Delete from %s", err.Error())
	}
	_ = res

	err = j.flushLogs(entries)
	if err != nil {
		t.Fatalf("Cannot flush logs %s", err.Error())
	}

	row := db.QueryRow("SELECT id FROM radius_audit_log;")
	if err := row.Err(); err != nil {
		t.Fatalf("Delete from %s", err.Error())
	}

	id := 0
	err = row.Scan(&id)
	if err != nil {
		t.Fatalf("Cannot flush logs %s", err.Error())
	}
}

func TestFlushRadiusAuditLogFromRedis(t *testing.T) {
	var entries [][]interface{} = make([][]interface{}, 1)
	json.Unmarshal([]byte(RADIUS_SAMPLE), &entries)
	job := NewFlushRadiusAuditLogJob(map[string]interface{}{
		"batch":       100.0,
		"type":        "flush_radius_audit_log_job",
		"status":      "enabled",
		"description": "Test",
		"schedule":    "@every 1m",
		"timeout":     1.0,
		"local":       "enabled",
	})
	ctx := context.Background()

	j := job.(*FlushRadiusAuditLogJob)
	db, err := getDb()
	if err != nil {
		t.Fatalf("No database %s", err.Error())
	}
	redis := redisClient()
	redis.Del(ctx, "RADIUS_AUDIT_LOG")
	redis.LPush(ctx, "RADIUS_AUDIT_LOG", RADIUS_ENTRY)

	res, err := db.Exec("DELETE FROM radius_audit_log;")
	if err != nil {
		t.Fatalf("Delete from %s", err.Error())
	}
	_ = res

	j.Run()

	row := db.QueryRow("SELECT id FROM radius_audit_log;")
	if err := row.Err(); err != nil {
		t.Fatalf("Delete from %s", err.Error())
	}

	id := 0
	err = row.Scan(&id)
	if err != nil {
		t.Fatalf("Cannot flush logs %s", err.Error())
	}
}
