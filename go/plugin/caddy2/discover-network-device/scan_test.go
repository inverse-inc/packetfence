package discovernetworkdevice

import (
	"math"
	"testing"
)

var badAddrLst = [][]string{
	{"192.168.0."},
	{"192.168.0.1", ""},
	{"192.168.0.1.8"},
	{"192.168.0.256"},
	{"192.168.0.1/33"},
	{"192.168.0.1/15"},
}

var badCredLst = []Credential{
	{Type: "deadbeef", SnmpRead: "public"},
	{Type: "", SnmpRead: "public"},
	{Type: "snmp_v2", SnmpRead: "public"},
	{Type: "snmp_v2c", SnmpRead: ""},
}

var badOptionsLst = []Options{
	{MaxThreads: -1, SnmpTimeout: 1, SnmpRetry: 1, SnmpPort: 161},
	{MaxThreads: 257, SnmpTimeout: 1, SnmpRetry: 1, SnmpPort: 161},
	{MaxThreads: 32, SnmpTimeout: 11, SnmpRetry: 1, SnmpPort: 161},
	{MaxThreads: 32, SnmpTimeout: -1, SnmpRetry: 1, SnmpPort: 161},
	{MaxThreads: 32, SnmpTimeout: 1, SnmpRetry: 11, SnmpPort: 161},
	{MaxThreads: 32, SnmpTimeout: 1, SnmpRetry: -1, SnmpPort: 161},
	{MaxThreads: 32, SnmpTimeout: 1, SnmpRetry: 1, SnmpPort: -1},
	{MaxThreads: 32, SnmpTimeout: 1, SnmpRetry: 1, SnmpPort: math.MaxUint16 + 1},
}

var goodAddrs = []string{"192.168.10.40", "192.168.10.41", "192.168.10.42"}
var goodCreds = []Credential{{Type: "snmp_v2c", SnmpRead: "public"}}
var goodOptions = Options{
	MaxThreads: 32, SnmpTimeout: 1, SnmpRetry: 1, SnmpPort: 161,
}

func progressCb(int) {}

func TestScanPayload(t *testing.T) {
	for _, badAddrs := range badAddrLst {
		t.Run("Should reject bad address", func(t *testing.T) {
			_, e := SnmpScan(Payload{Credentials: goodCreds, Addresses: badAddrs}, progressCb)
			if e == nil {
				t.Errorf("Address must be rejected: %v", badAddrs)
			}
		})
	}
	for _, badCred := range badCredLst {
		t.Run("Should reject bad credentials", func(t *testing.T) {
			_, e := SnmpScan(Payload{Credentials: []Credential{badCred}, Addresses: goodAddrs}, progressCb)
			if e == nil {
				t.Errorf("Credential must be rejected: %v", badCred)
			}
		})
	}
	for _, badOptions := range badOptionsLst {
		t.Run("Should reject bad options", func(t *testing.T) {
			_, e := SnmpScan(Payload{Options: badOptions, Credentials: goodCreds, Addresses: goodAddrs}, progressCb)
			if e == nil {
				t.Errorf("Options must be rejected: %v", badOptions)
			}
		})
	}
	t.Run("Should scan", func(t *testing.T) {
		r, e := SnmpScan(Payload{Credentials: goodCreds, Addresses: goodAddrs, Options: goodOptions}, progressCb)
		if r == nil || e != nil {
			t.Errorf("Scan should answer correctly: %v", e)
		}
	})
}
