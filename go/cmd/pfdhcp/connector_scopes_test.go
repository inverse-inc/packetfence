package main

import (
	"testing"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// The fingerprint changes with the DHCP-enabled connector interfaces and only
// with them, whatever their order.
func TestConnectorScopesFingerprint(t *testing.T) {
	scope := pfconfigdriver.ConnectorInterface{Parent: "ens19", CIDR: "192.0.2.1/24", Dhcp: "enabled", DhcpStart: "192.0.2.10", DhcpEnd: "192.0.2.254"}
	other := pfconfigdriver.ConnectorInterface{Parent: "ens20", Vlan: 30, CIDR: "198.51.100.1/24", Dhcp: "enabled", DhcpStart: "198.51.100.10", DhcpEnd: "198.51.100.20"}
	noDhcp := pfconfigdriver.ConnectorInterface{Parent: "ens21", CIDR: "203.0.113.1/24", Dhcp: "disabled"}
	conf := func(ifaces ...pfconfigdriver.ConnectorInterface) pfconfigdriver.Connectors {
		return pfconfigdriver.Connectors{Element: map[string]pfconfigdriver.ConnectorConfig{"c1": {Interfaces: ifaces, Description: "site"}}}
	}

	base := connectorScopesFingerprint(conf(scope, other))
	if connectorScopesFingerprint(conf(other, scope)) != base {
		t.Errorf("order must not matter")
	}
	if connectorScopesFingerprint(conf(scope, other, noDhcp)) != base {
		t.Errorf("an interface without DHCP must not matter")
	}
	changed := scope
	changed.DhcpEnd = "192.0.2.100"
	if connectorScopesFingerprint(conf(changed, other)) == base {
		t.Errorf("a changed range must change the fingerprint")
	}
	if connectorScopesFingerprint(conf(scope)) == base {
		t.Errorf("a removed scope must change the fingerprint")
	}
	if connectorScopesFingerprint(pfconfigdriver.Connectors{}) != connectorScopesFingerprint(conf(noDhcp)) {
		t.Errorf("no DHCP scope at all must fingerprint the same")
	}
}

// The connector interface is looked up apart from the local ones and can be
// swapped or removed at runtime.
func TestLookupConnectorInterface(t *testing.T) {
	intNametoInterface = map[string]*Interface{"eth1": {Name: "eth1"}}
	setConnectorInterface(nil)
	defer setConnectorInterface(nil)
	if _, ok := lookupInterface(ConnectorInterfaceName); ok {
		t.Fatalf("no connector interface expected")
	}
	if i, ok := lookupInterface("eth1"); !ok || i.Name != "eth1" {
		t.Fatalf("local interface lookup")
	}
	setConnectorInterface(&Interface{Name: ConnectorInterfaceName, InterfaceType: ConnectorInterfaceType})
	if i, ok := lookupInterface(ConnectorInterfaceName); !ok || i.InterfaceType != ConnectorInterfaceType {
		t.Fatalf("connector interface lookup")
	}
	DHCPConfig = newDHCPConfig()
	if n := len(servedInterfaces()); n != 1 {
		t.Errorf("served interfaces: %d", n)
	}
}
