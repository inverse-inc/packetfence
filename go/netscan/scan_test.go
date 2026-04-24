package netscan_test

import (
	"context"
	"math"
	"os/exec"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/netscan"
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

var badCredLst = []netscan.Credential{
	{Type: "deadbeef", Value: "public"},
	{Type: "", Value: "public"},
	{Type: "snmp_v2", Value: "public"},
	{Type: netscan.CRED_TYPE_SNMP_V1, Value: ""},
	{Type: netscan.CRED_TYPE_SNMP_V2C, Value: ""},
}

var badOptionsLst = []netscan.Options{
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
var goodCreds = []netscan.Credential{{Type: netscan.CRED_TYPE_SNMP_V2C, Value: "public"}}
var goodOptions = netscan.Options{
	MaxThreads: 32, SnmpTimeout: 1, SnmpRetry: 1, SnmpPort: 161,
}

func progressCb(int, string) {}

func TestScanScanRequest(t *testing.T) {
	for _, badAddrs := range badAddrLst {
		t.Run("Should reject bad address", func(t *testing.T) {
			_, e := netscan.SnmpScan(ctx, netscan.ScanRequest{Credentials: goodCreds, Addresses: badAddrs})
			if e == nil {
				t.Errorf("Address must be rejected: %v", badAddrs)
			}
		})
	}
	for _, badCred := range badCredLst {
		t.Run("Should reject bad credentials", func(t *testing.T) {
			_, e := netscan.SnmpScan(ctx, netscan.ScanRequest{Credentials: []netscan.Credential{badCred}, Addresses: goodAddrs})
			if e == nil {
				t.Errorf("Credential must be rejected: %v", badCred)
			}
		})
	}
	for _, badOptions := range badOptionsLst {
		t.Run("Should reject bad options", func(t *testing.T) {
			_, e := netscan.SnmpScan(ctx, netscan.ScanRequest{Options: badOptions, Credentials: goodCreds, Addresses: goodAddrs})
			if e == nil {
				t.Errorf("Options must be rejected: %v", badOptions)
			}
		})
	}
	t.Run("Should scan", func(t *testing.T) {
		r, e := netscan.SnmpScan(ctx, netscan.ScanRequest{Credentials: goodCreds, Addresses: []string{"192.168.42.42"}, Options: goodOptions})
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
	_, err = netscan.SnmpScan(ctx, netscan.ScanRequest{Credentials: goodCreds, Addresses: []string{ipAddress}, Options: goodOptions})
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
	_, err = netscan.SnmpScan(subCtx, netscan.ScanRequest{Credentials: goodCreds, Addresses: []string{ipAddress}, Options: goodOptions}, netscan.WithProgress(progressCb))
	if err != nil {
		if !strings.Contains(err.Error(), "context deadline exceeded") {
			t.Errorf("Error while SnmpScan (not the actual test): %v", err) // that's not what we test
		}
	}
	timeElapsed := time.Since(timeStart)
	if timeElapsed.Seconds() > 20 { // it can take some times to finish
		t.Errorf("SnmpScan didn't timeout in time")
	}
}
