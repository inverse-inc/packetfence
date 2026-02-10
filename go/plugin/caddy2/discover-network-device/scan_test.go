package discovernetworkdevice

import (
	"context"
	"math"
	"os/exec"
	"regexp"
	"strings"
	"testing"
	"time"
)

var ctx context.Context = context.Background()

var badAddrLst = [][]string{
	{"192.168.0."},
	{"192.168.0.1", ""},
	{"192.168.0.1.8"},
	{"192.168.0.256"},
	{"192.168.0.1/33"},
	{"192.168.0.1/15"},
}

var badCredLst = []SnmpCred{
	{Version: "deadbeef", CommunityRead: "public"},
	{Version: "", CommunityRead: "public"},
	{Version: "snmp_v2", CommunityRead: "public"},
	{Version: CRED_TYPE_SNMP_V1, CommunityRead: ""},
	{Version: CRED_TYPE_SNMP_V2C, CommunityRead: ""},
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
var goodCreds = []SnmpCred{{Version: CRED_TYPE_SNMP_V2C, CommunityRead: "public"}}
var goodOptions = Options{
	MaxThreads: 32, SnmpTimeout: 1, SnmpRetry: 1, SnmpPort: 161,
}

func progressCb(int, string) {}

func TestScanPayload(t *testing.T) {
	for _, badAddrs := range badAddrLst {
		t.Run("Should reject bad address", func(t *testing.T) {
			_, e := SnmpScan(ctx, Payload{Credentials: goodCreds, Addresses: badAddrs}, progressCb)
			if e == nil {
				t.Errorf("Address must be rejected: %v", badAddrs)
			}
		})
	}
	for _, badCred := range badCredLst {
		t.Run("Should reject bad credentials", func(t *testing.T) {
			_, e := SnmpScan(ctx, Payload{Credentials: []SnmpCred{badCred}, Addresses: goodAddrs}, progressCb)
			if e == nil {
				t.Errorf("Credential must be rejected: %v", badCred)
			}
		})
	}
	for _, badOptions := range badOptionsLst {
		t.Run("Should reject bad options", func(t *testing.T) {
			_, e := SnmpScan(ctx, Payload{Options: badOptions, Credentials: goodCreds, Addresses: goodAddrs}, progressCb)
			if e == nil {
				t.Errorf("Options must be rejected: %v", badOptions)
			}
		})
	}
	t.Run("Should scan", func(t *testing.T) {
		r, e := SnmpScan(ctx, Payload{Credentials: goodCreds, Addresses: []string{"192.168.42.42"}, Options: goodOptions}, progressCb)
		if r == nil || e != nil {
			t.Errorf("Scan should answer correctly: %v", e)
		}
	})
}

// TestScanSnmp uses tcpdump to check if a SNMP request has been sent
// The test can fail depending of the environment, even if the feature is working
func TestScanSnmp(t *testing.T) {
	var err error
	ipAddress := "192.168.42.42"
	cmd := exec.Command("tcpdump", "-i", "any", "port", "161", "-U", "-l", "-c", "32")
	outPipe, err := cmd.StdoutPipe()
	if err != nil {
		t.Errorf("Error running exec.Command StdoutPipe: %v", err)
	}
	if err := cmd.Start(); err != nil {
		t.Errorf("Error running tcpdump for test: %v", err)
	}
	time.Sleep(time.Second * 1) // wait for tcpdump to be ready
	_, err = SnmpScan(ctx, Payload{Credentials: goodCreds, Addresses: []string{ipAddress}, Options: goodOptions}, progressCb)
	if err != nil {
		t.Errorf("Error while SnmpScan (not the actual test): %v", err) // that's not what we test
	}
	cmd.Process.Kill() // Read blocks if process is not stopped
	tmp := make([]byte, 1024*32)
	_, err = outPipe.Read(tmp)
	cmd.Wait()
	reg := regexp.MustCompile(`> 192\.168\.42\.42\.snmp\:\s+GetRequest\(\d+\)\s+system\.sysDescr\.0 system\.sysObjectID\.0 system\.sysName\.0`)
	if !reg.Match(tmp) {
		t.Errorf("No SNMP request were send to %s", ipAddress)
	}
}

func TestScanTimeout(t *testing.T) {
	var err error
	ipAddress := "192.168.42.42/16"
	subCtx, cancel := context.WithTimeout(ctx, time.Second*1)
	defer cancel()
	timeStart := time.Now()
	_, err = SnmpScan(subCtx, Payload{Credentials: goodCreds, Addresses: []string{ipAddress}, Options: goodOptions}, progressCb)
	if err != nil {
		if !strings.Contains(err.Error(), "context deadline exceeded") {
			t.Errorf("Error while SnmpScan (not the actual test): %v", err) // that's not what we test
		} else {
			t.Logf("Scan was cancelled: %s", err.Error())
		}
	}
	timeElapsed := time.Since(timeStart)
	if timeElapsed.Seconds() > 20 { // it can take some times to finish
		t.Errorf("SnmpScan didn't timeout in time")
	}
}
