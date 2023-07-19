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
	redis.LPush(ctx, "RADIUS_AUDIT_LOG", RADIUS_ENTRY, RADIUS_ENTRY)

	res, err := db.Exec("DELETE FROM radius_audit_log;")
	if err != nil {
		t.Fatalf("Delete from %s", err.Error())
	}
	_ = res

	j.Run()

	row := db.QueryRow("SELECT COUNT(id) FROM radius_audit_log;")
	if err := row.Err(); err != nil {
		t.Fatalf("Delete from %s", err.Error())
	}

	count := 0
	err = row.Scan(&count)
	if err != nil {
		t.Fatalf("Cannot flush logs %s", err.Error())
	}

	if count != 2 {
		t.Fatalf("Flush count logs expect %d, got %d", 2, count)
	}
}

func MapKeys[K comparable, V any](m map[K]V) []K {
	keys := make([]K, 0, len(m))
	for k, _ := range m {
		keys = append(keys, k)
	}

	return keys
}

const RADIUS_ENTRY2 = `
[
  "Accept",
  {
    "User-Name": {
      "type": "string",
      "value": [
        "000300111101"
      ]
    },
    "User-Password": {
      "type": "string",
      "value": [
        "******",
        "*"
      ]
    },
    "NAS-IP-Address": {
      "type": "ipaddr",
      "value": "172.18.120.201"
    },
    "NAS-Port": {
      "type": "integer",
      "value": 8
    },
    "Service-Type": {
      "type": "integer",
      "value": "Call-Check"
    },
    "Framed-MTU": {
      "type": "integer",
      "value": 1400
    },
    "Called-Station-Id": {
      "type": "string",
      "value": "44-38-39-00-00-12:"
    },
    "Calling-Station-Id": {
      "type": "string",
      "value": "00:03:00:11:11:01"
    },
    "NAS-Identifier": {
      "type": "string",
      "value": "localhost"
    },
    "NAS-Port-Type": {
      "type": "integer",
      "value": "Ethernet"
    },
    "Acct-Session-Id": {
      "type": "string",
      "value": "EE4C43AD30EB4C8C"
    },
    "Event-Timestamp": {
      "type": "date",
      "value": "Jul 17 2023 21:10:18 UTC"
    },
    "Message-Authenticator": {
      "type": "octets",
      "value": "0x439a666a595f9c98538e1ce1b8ed8f34"
    },
    "NAS-Port-Id": {
      "type": "string",
      "value": "swp12"
    },
    "Stripped-User-Name": {
      "type": "string",
      "value": "000300111101"
    },
    "Realm": {
      "type": "string",
      "value": "null"
    },
    "FreeRADIUS-Client-IP-Address": {
      "type": "ipaddr",
      "value": "172.18.120.201"
    },
    "PacketFence-KeyBalanced": {
      "type": "string",
      "value": "d0765eaba49810c0c2578385bc6272b2"
    },
    "PacketFence-Radius-Ip": {
      "type": "string",
      "value": "172.18.120.15"
    }
  },
  {
    "REST-HTTP-Status-Code": {
      "type": "integer",
      "value": 200
    },
    "Tunnel-Medium-Type": {
      "type": "integer",
      "value": "IEEE-802"
    },
    "Tunnel-Type": {
      "type": "integer",
      "value": "VLAN"
    },
    "Tunnel-Private-Group-Id": {
      "type": "string",
      "value": "100"
    }
  },
  {
    "PacketFence-Switch-Id": {
      "type": "string",
      "value": "44:38:39:00:00:12"
    },
    "PacketFence-Switch-Mac": {
      "type": "string",
      "value": "44:38:39:00:00:12"
    },
    "PacketFence-Switch-Ip-Address": {
      "type": "string",
      "value": "172.18.120.201"
    },
    "PacketFence-IfIndex": {
      "type": "string",
      "value": "8"
    },
    "PacketFence-Connection-Type": {
      "type": "string",
      "value": "Ethernet-NoEAP"
    },
    "Auth-Type": {
      "type": "integer",
      "value": "Accept"
    },
    "PacketFence-Role": {
      "type": "string",
      "value": "headless_device"
    },
    "PacketFence-Status": {
      "type": "string",
      "value": "reg"
    },
    "PacketFence-Profile": {
      "type": "string",
      "value": "catch_wired_mac_authentication"
    },
    "PacketFence-AutoReg": {
      "type": "string",
      "value": "0"
    },
    "PacketFence-IsPhone": {
      "type": "string",
      "value": ""
    },
    "PacketFence-Request-Time": {
      "type": "integer",
      "value": 0
    }
  }
]
`

const REQUEST_EXPECTED = `Acct-Session-Id = "EE4C43AD30EB4C8C",
Called-Station-Id = "44-38-39-00-00-12:",
Calling-Station-Id = "00:03:00:11:11:01",
Event-Timestamp = "Jul 17 2023 21:10:18 UTC",
Framed-MTU = "1400",
FreeRADIUS-Client-IP-Address = "172.18.120.201",
Message-Authenticator = "0x439a666a595f9c98538e1ce1b8ed8f34",
NAS-IP-Address = "172.18.120.201",
NAS-Identifier = "localhost",
NAS-Port = "8",
NAS-Port-Id = "swp12",
NAS-Port-Type = "Ethernet",
PacketFence-KeyBalanced = "d0765eaba49810c0c2578385bc6272b2",
PacketFence-Radius-Ip = "172.18.120.15",
Realm = "null",
Service-Type = "Call-Check",
Stripped-User-Name = "000300111101",
User-Name = "000300111101",
User-Password = "******",
User-Password = "*"`

func TestToRequest(t *testing.T) {
	var entry []interface{} = make([]interface{}, 4)
	if err := json.Unmarshal([]byte(RADIUS_ENTRY2), &entry); err != nil {
		t.Fatalf("Error: %s", err.Error())
	}

	request := formatRequest(entry[1].(map[string]interface{}))
	if request != REQUEST_EXPECTED {
		t.Fatalf("Expected \n%s\nGot\n%s\n", REQUEST_EXPECTED, request)
	}

}
