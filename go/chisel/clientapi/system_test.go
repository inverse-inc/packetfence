package clientapi

import "testing"

// Docker's interfaces are not offered as site interfaces; everything else is.
func TestIsContainerInterface(t *testing.T) {
	for name, want := range map[string]bool{
		"docker0":       true,
		"br-1a2b3c4d5e": true,
		"veth12ab34":    true,
		"ens18":         false,
		"ens18.22":      false,
		"eth0":          false,
		"bond0":         false,
		"br0":           false, // an operator bridge, not a docker network
		"vlan100":       false,
	} {
		if got := isContainerInterface(name); got != want {
			t.Errorf("isContainerInterface(%q) = %v, want %v", name, got, want)
		}
	}
}
