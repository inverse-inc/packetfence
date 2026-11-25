package pfdns

import (
	"context"
	"regexp"
	"testing"
)

func matchesAny(fqdnPort map[*regexp.Regexp][]string, qname string) bool {
	for rgx := range fqdnPort {
		if rgx.MatchString(qname) {
			return true
		}
	}
	return false
}

func TestPassthroughs(t *testing.T) {
	fqdnPort := make(map[*regexp.Regexp][]string)
	addPassthroughs(
		context.Background(),
		fqdnPort,
		map[string][]string{"example.com": {"tcp:443"}},
		map[string][]string{"login.microsoftonline.com": {"tcp:443"}, "Mixed.Case.org": {"tcp:80"}},
	)

	for _, test := range []struct {
		qname    string
		expected bool
	}{
		// wildcard *.example.com
		{"example.com.", true},
		{"www.example.com.", true},
		{"a.b.example.com.", true},
		{"WWW.Example.COM.", true},
		{"www.example.com", true},
		{"example.com.other.net.", false},
		{"badexample.com.", false},
		{"examplexcom.", false},
		// normal login.microsoftonline.com
		{"login.microsoftonline.com.", true},
		{"login.microsoftonline.com", true},
		{"LOGIN.microsoftonline.com.", true},
		{"login-microsoftonline.com.", false},
		{"loginxmicrosoftonline.com.", false},
		{"www.login.microsoftonline.com.", false},
		{"login.microsoftonline.com.other.net.", false},
		{"mixed.case.org.", true},
	} {
		if got := matchesAny(fqdnPort, test.qname); got != test.expected {
			t.Errorf("passthrough match of %q: got %v, expected %v", test.qname, got, test.expected)
		}
	}
}

func TestEmptyNames(t *testing.T) {
	if _, err := domainRegexp(" ", true); err == nil {
		t.Errorf("an empty passthrough is refused")
	}
	if _, err := domainServicesRegexp(""); err == nil {
		t.Errorf("an empty domain is refused")
	}
	if _, err := domainRegexp(".", false); err == nil {
		t.Errorf("a passthrough of the root only is refused")
	}
}

func TestDomainServicesRegexp(t *testing.T) {
	rgx, err := domainServicesRegexp("corp.local")
	if err != nil {
		t.Fatalf("Cannot compile: %s", err)
	}

	for _, test := range []struct {
		qname    string
		expected bool
	}{
		{"_ldap._tcp.dc._msdcs.corp.local.", true},
		{"_ldap._tcp.Default-First-Site-Name._sites.dc._msdcs.corp.local.", true},
		{"_kerberos._tcp.Default-First-Site-Name._sites.corp.local.", true},
		{"0c1e2f3a-1111-2222-3333-444455556666._msdcs.corp.local.", true},
		{"_msdcs.corp.local.", true},
		{"_ldap._tcp.dc._msdcs.CORP.LOCAL", true},
		{"_msdcs.corp.local.other.net.", false},
		{"_sites.corp.local.other.net.", false},
		{"x_msdcs.corp.local.", false},
		{"_msdcsxcorp.local.", false},
		{"_msdcs.corpxlocal.", false},
		{"www.corp.local.", false},
	} {
		if got := rgx.MatchString(test.qname); got != test.expected {
			t.Errorf("domain services match of %q: got %v, expected %v", test.qname, got, test.expected)
		}
	}
}

func TestDomainRegexpPortal(t *testing.T) {
	rgx, err := domainRegexp("packetfence.example.org", true)
	if err != nil {
		t.Fatalf("Cannot compile: %s", err)
	}

	for _, test := range []struct {
		qname    string
		expected bool
	}{
		{"packetfence.example.org.", true},
		{"www.packetfence.example.org.", true},
		{"packetfence.example.org.other.net.", false},
		{"notpacketfence.example.org.", false},
		{"packetfencexexample.org.", false},
	} {
		if got := rgx.MatchString(test.qname); got != test.expected {
			t.Errorf("portal FQDN match of %q: got %v, expected %v", test.qname, got, test.expected)
		}
	}
}
