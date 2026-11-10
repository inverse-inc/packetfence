package pfdns

import "testing"

func TestDnsFilterScope(t *testing.T) {
	for networkType, want := range map[string]string{
		"inlinel2":                    "inline",
		"inlinel3":                    "inline",
		"vlan-isolation":              "isolation",
		"vlan-registration":           "registration",
		"vlan-registration,radius":    "registration",
		"dns-enforcement":             "dnsenforcement",
		"dns-enforcement,radius":      "dnsenforcement",
		"dns-enforcement,dhcp,portal": "dnsenforcement",
		"other":                       "",
		"":                            "",
	} {
		if got := dnsFilterScope(networkType); got != want {
			t.Errorf("dnsFilterScope(%q) = %q, want %q", networkType, got, want)
		}
	}
}
