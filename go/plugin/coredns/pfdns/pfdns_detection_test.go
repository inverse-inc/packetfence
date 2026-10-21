package pfdns

import (
	"context"
	"testing"
)

func TestCheckDetectionMechanisms(t *testing.T) {
	ctx := context.Background()
	pf := &pfdns{}
	for _, host := range []string{"www.gstatic.com", "g.cn", "captive.apple.com"} {
		if err := pf.addDetectionMechanismsToList(ctx, host); err != nil {
			t.Fatalf("Cannot add %s: %s", host, err)
		}
	}

	for _, test := range []struct {
		qname    string
		expected bool
	}{
		{"www.gstatic.com.", true},
		{"WWW.GStatic.com.", true},
		{"g.cn.", true},
		{"captive.apple.com", true},
		{"img.cnn.com.", false},
		{"gxcn.example.com.", false},
		{"fonts.gstatic.com.", false},
		{"www.gstatic.com.example.net.", false},
		{"notcaptive.apple.com.", false},
	} {
		if got := pf.checkDetectionMechanisms(ctx, test.qname); got != test.expected {
			t.Errorf("checkDetectionMechanisms(%s) = %t, expected %t", test.qname, got, test.expected)
		}
	}
}

func TestDetectionMechanismHost(t *testing.T) {
	for _, test := range []struct {
		url      string
		expected string
		valid    bool
	}{
		{"http://www.gstatic.com/generate_204", "www.gstatic.com", true},
		{"http://captive.apple.com", "captive.apple.com", true},
		{"https://detect.example.com:8443/check", "detect.example.com", true},
		{"captive.example.com", "", false},
		{"", "", false},
	} {
		host, err := detectionMechanismHost(test.url)
		if (err == nil) != test.valid || host != test.expected {
			t.Errorf("detectionMechanismHost(%q) = %q, %v, expected %q (valid: %t)", test.url, host, err, test.expected, test.valid)
		}
	}
}
