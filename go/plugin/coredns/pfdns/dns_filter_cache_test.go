package pfdns

import (
	"errors"
	"testing"
	"time"

	"github.com/miekg/dns"
	cache "github.com/patrickmn/go-cache"
)

func TestMakeKeyCacheDistinguishesQueries(t *testing.T) {
	pf := &pfdns{}
	base := pf.MakeKeyCache("00:11:22:33:44:55", "default", false, "example.com.", dns.TypeA)
	for name, key := range map[string]string{
		"qtype":         pf.MakeKeyCache("00:11:22:33:44:55", "default", false, "example.com.", dns.TypeAAAA),
		"mac":           pf.MakeKeyCache("00:11:22:33:44:66", "default", false, "example.com.", dns.TypeA),
		"category":      pf.MakeKeyCache("00:11:22:33:44:55", "guest", false, "example.com.", dns.TypeA),
		"securityEvent": pf.MakeKeyCache("00:11:22:33:44:55", "default", true, "example.com.", dns.TypeA),
		"qname":         pf.MakeKeyCache("00:11:22:33:44:55", "default", false, "example.org.", dns.TypeA),
	} {
		if key == base {
			t.Errorf("changing the %s does not change the cache key %q", name, key)
		}
	}

	if got := pf.MakeKeyCache("00:11:22:33:44:55", "default", false, "example.com.", dns.TypeA); got != base {
		t.Errorf("same query gave cache key %q, want %q", got, base)
	}

	// Moving characters between fields gives another key.
	for _, test := range [][2]string{
		{pf.MakeKeyCache("mac", "ab", false, "c.", dns.TypeA), pf.MakeKeyCache("mac", "a", false, "bc.", dns.TypeA)},
		{pf.MakeKeyCache("mac", "a", false, "false|example.com.", dns.TypeA), pf.MakeKeyCache("mac", "a|false", false, "example.com.", dns.TypeA)},
	} {
		if test[0] == test[1] {
			t.Errorf("different queries share the cache key %q", test[0])
		}
	}
}

func TestDnsFilterAnswerCachesPerQtype(t *testing.T) {
	pf := &pfdns{}
	c := cache.New(time.Minute, time.Minute)
	answers := map[uint16]string{
		dns.TypeA:    "example.com. 30 IN A 192.0.2.1",
		dns.TypeAAAA: "example.com. 30 IN AAAA 2001:db8::1",
	}
	calls := map[uint16]int{}
	query := func(qtype uint16) (string, bool) {
		t.Helper()
		key := pf.MakeKeyCache("00:11:22:33:44:55", "default", false, "example.com.", qtype)
		got, cached, err := dnsFilterAnswer(c, key, func() (string, error) {
			calls[qtype]++
			return answers[qtype], nil
		})
		if err != nil {
			t.Fatalf("qtype %s: %s", dns.TypeToString[qtype], err)
		}
		return got, cached
	}

	for i := 0; i < 2; i++ {
		for _, qtype := range []uint16{dns.TypeA, dns.TypeAAAA} {
			got, cached := query(qtype)
			if got != answers[qtype] {
				t.Errorf("round %d qtype %s: got %q, want %q", i, dns.TypeToString[qtype], got, answers[qtype])
			}
			if cached != (i == 1) {
				t.Errorf("round %d qtype %s: cached = %v, want %v", i, dns.TypeToString[qtype], cached, i == 1)
			}
		}
	}

	for _, qtype := range []uint16{dns.TypeA, dns.TypeAAAA} {
		if calls[qtype] != 1 {
			t.Errorf("pffilter called %d times for qtype %s, want 1 (second lookup should come from the cache)", calls[qtype], dns.TypeToString[qtype])
		}
	}
}

func TestDnsFilterAnswerError(t *testing.T) {
	c := cache.New(time.Minute, time.Minute)
	wantErr := errors.New("no match")
	calls := 0
	for i := 0; i < 2; i++ {
		_, _, err := dnsFilterAnswer(c, "key", func() (string, error) {
			calls++
			return "", wantErr
		})
		if !errors.Is(err, wantErr) {
			t.Fatalf("got error %v, want %v", err, wantErr)
		}
	}
	// A failed lookup is not served from the cache: pffilter is asked again.
	if calls != 2 {
		t.Errorf("pffilter called %d times, want 2", calls)
	}
}
