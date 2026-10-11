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
