package logtailer

import (
	"testing"
	"time"
)

func TestRsyslogMetaEngine(t *testing.T) {
	line := `Apr 07 17:12:00 pf pfipset[2126]: lvl=info msg="Request isn't authorized, performing login against the Unified API" pid=2126 request-uuid=90505d47-8880-11ea-95cd-0050569c7a2d`
	res := NewRsyslogMetaEngine().ExtractMeta(line)
	if res.Timestamp.Year() != time.Now().Year() {
		t.Error("Unexpected timestamp year", res.Timestamp.Year())
	}
	if res.Timestamp.Month() != 4 {
		t.Error("Unexpected timestamp month", res.Timestamp.Month())
	}
	if res.Timestamp.Day() != 7 {
		t.Error("Unexpected timestamp day", res.Timestamp.Day())
	}
	if res.Timestamp.Hour() != 17 {
		t.Error("Unexpected timestamp hour", res.Timestamp.Hour())
	}
	if res.Timestamp.Minute() != 12 {
		t.Error("Unexpected timestamp hour", res.Timestamp.Minute())
	}
	if res.Timestamp.Second() != 00 {
		t.Error("Unexpected timestamp hour", res.Timestamp.Second())
	}
	if res.Hostname != "pf" {
		t.Error("Unexpected hostname", res.Hostname)
	}
	if res.SyslogName != "pfipset" {
		t.Error("Unexpected syslog name", res.SyslogName)
	}
	if res.Process != "pfipset" {
		t.Error("Unexpected process name", res.Process)
	}
	if res.LogLevel != logInfo {
		t.Error("Unexpected log level", res.LogLevel)
	}
}

func TestFreeradiusMetaExtractor(t *testing.T) {
	line := `Apr 27 06:07:12 vpf1 load_balancer[20680]: (16781086) Login OK: [9c4e36c5d534] (from client 1.2.3.4/32 port 0 cli 00-11-22-33-44-55) - Proxied to: 10.1.15.13`
	res := NewRsyslogMetaEngine().ExtractMeta(line)
	if res.LogLevel != logInfo {
		t.Error("Unexpected log level", res.LogLevel)
	}
	if res.Process != "radiusd" {
		t.Error("Unexpected process name", res.Process)
	}

	line = `Apr 27 05:53:49 pf7-1 auth[11054]: tls: TLS_accept: Error in SSLv3 read client key exchange A`
	res = NewRsyslogMetaEngine().ExtractMeta(line)
	if res.LogLevel != logError {
		t.Error("Unexpected log level", res.LogLevel)
	}
	if res.Process != "radiusd" {
		t.Error("Unexpected process name", res.Process)
	}
}

func TestGolangMetaExtractor(t *testing.T) {
	line := `Apr 24 07:44:40 vpf1 pfsso[19908]: t=2020-04-24T07:44:40-0400 lvl=eror msg="Cannot stat /usr/local/pf/var/control/config::Firewall_SSO()-control. Will consider resource as invalid" pid=19908 request-uuid=ed738e25-5e1a-11ea-9927-005056a208eb PfconfigObject=keys|config::Firewall_SSO()`
	res := NewRsyslogMetaEngine().ExtractMeta(line)
	if res.LogLevel != logError {
		t.Error("Unexpected log level", res.LogLevel)
	}
	if res.Process != "pfsso" {
		t.Error("Unexpected process name", res.Process)
	}
}

func TestLog4perlMetaExtractor(t *testing.T) {
	line := `Apr 24 15:30:50 vpf1 packetfence_httpd.aaa: httpd.aaa(20139) INFO: [mac:00:11:22:33:44:55] (1.2.3.4) Added VLAN 232 to the returned RADIUS Access-Accept (pf::Switch::returnRadiusAccessAccept)`
	res := NewRsyslogMetaEngine().ExtractMeta(line)
	if res.LogLevel != logInfo {
		t.Error("Unexpected log level", res.LogLevel)
	}
	if res.Process != "httpd.aaa" {
		t.Error("Unexpected process name", res.Process)
	}
}

func TestApacheAccessMetaExtractor(t *testing.T) {
	line := `Apr 27 04:14:46 pf7-1 httpd_aaa: 127.0.0.1 - - [27/Apr/2020:04:14:46 -0400] "POST //radius/rest/authorize HTTP/1.1" 200 1153 2019 171785 "-" "FreeRADIUS 3.0.18" "127.0.0.1:7070"`
	res := NewRsyslogMetaEngine().ExtractMeta(line)
	if res.LogLevel != logInfo {
		t.Error("Unexpected log level", res.LogLevel)
	}
	if res.Process != "httpd.aaa" {
		t.Error("Unexpected process name", res.Process)
	}
}

func TestApacheErrorMetaExtractor(t *testing.T) {
	line := `Apr 27 08:36:13 vpf1 httpd_aaa_err: Use of uninitialized value $roleName in hash element at /usr/local/pf/lib/pf/Switch.pm line 591.`
	res := NewRsyslogMetaEngine().ExtractMeta(line)
	if res.LogLevel != logError {
		t.Error("Unexpected log level", res.LogLevel)
	}
	if res.Process != "httpd.aaa" {
		t.Error("Unexpected process name", res.Process)
	}
}

func TestLogWithoutPrefix(t *testing.T) {
	line := "May  5 15:17:20 packetfence pfipset[5249]: t=2020-05-05T15:17:20-0400 lvl=info msg=\"Reloading ipsets\" pid=5249"
	res := NewRsyslogMetaEngine().ExtractMeta(line)

	if res.LogWithoutPrefix != "t=2020-05-05T15:17:20-0400 lvl=info msg=\"Reloading ipsets\" pid=5249" {
		t.Error("Unexpected value for LogWithoutPrefix", res.LogWithoutPrefix)
	}

	line = `Apr 27 08:36:13 vpf1 httpd_aaa_err: Use of uninitialized value $roleName in hash element at /usr/local/pf/lib/pf/Switch.pm line 591.`
	res = NewRsyslogMetaEngine().ExtractMeta(line)

	if res.LogWithoutPrefix != "Use of uninitialized value $roleName in hash element at /usr/local/pf/lib/pf/Switch.pm line 591." {
		t.Error("Unexpected value for LogWithoutPrefix", res.LogWithoutPrefix)
	}

}
