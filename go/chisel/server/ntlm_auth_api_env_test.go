package chserver

import (
	"net"
	"testing"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// ownerLookup returns an ownerForIP func backed by a static ad_server-IP ->
// connector-id map, standing in for ConnectorsContainer.ForIP in tests.
func ownerLookup(byIP map[string]string) func(net.IP) string {
	return func(ip net.IP) string {
		if ip == nil {
			return ""
		}
		return byIP[ip.String()]
	}
}

func TestMaskDomainSecretsForConnector(t *testing.T) {
	const realPass = "S3cretMachineAcctP@ss"

	// owns its AD: 10.0.0.0/8 -> connectorA, 192.168.0.0/16 -> connectorB
	owners := ownerLookup(map[string]string{
		"10.0.0.5":    "connectorA",
		"192.168.1.7": "connectorB",
	})

	domains := func() map[string]pfconfigdriver.Domain {
		return map[string]pfconfigdriver.Domain{
			"domA":   {AdServer: "10.0.0.5", UseConnector: "enabled", MachineAccountPassword: realPass},
			"domB":   {AdServer: "192.168.1.7", UseConnector: "enabled", MachineAccountPassword: realPass},
			"domOff": {AdServer: "10.0.0.5", UseConnector: "disabled", MachineAccountPassword: realPass},
		}
	}

	cases := []struct {
		name        string
		connectorID string
		// wantPass maps domain -> expected machine_account_password; a domain
		// absent from the map must be absent from the output.
		wantPass map[string]string
	}{
		{
			name:        "owner gets real secret for owned domain, masks the rest",
			connectorID: "connectorA",
			wantPass: map[string]string{
				"domA": realPass,
				"domB": fakeMachineAccountPassword,
			},
		},
		{
			name:        "other owner: real for its own, masked for the rest",
			connectorID: "connectorB",
			wantPass: map[string]string{
				"domA": fakeMachineAccountPassword,
				"domB": realPass,
			},
		},
		{
			name:        "non-owning connector: everything masked",
			connectorID: "connectorZ",
			wantPass: map[string]string{
				"domA": fakeMachineAccountPassword,
				"domB": fakeMachineAccountPassword,
			},
		},
		{
			name:        "unidentified caller (empty id): everything masked",
			connectorID: "",
			wantPass: map[string]string{
				"domA": fakeMachineAccountPassword,
				"domB": fakeMachineAccountPassword,
			},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			src := domains()
			got := maskDomainSecretsForConnector(src, tc.connectorID, owners)

			if len(got) != len(tc.wantPass) {
				t.Fatalf("domain count = %d, want %d (got keys %v)", len(got), len(tc.wantPass), keys(got))
			}
			// use_connector=disabled domains must never be returned.
			if _, ok := got["domOff"]; ok {
				t.Errorf("domOff (use_connector disabled) should be excluded but was returned")
			}
			for dom, want := range tc.wantPass {
				d, ok := got[dom]
				if !ok {
					t.Errorf("expected domain %q in output, missing", dom)
					continue
				}
				if d.MachineAccountPassword != want {
					t.Errorf("domain %q: machine_account_password = %q, want %q", dom, d.MachineAccountPassword, want)
				}
			}

			// The source map must not be mutated by the masking.
			if src["domB"].MachineAccountPassword != realPass {
				t.Errorf("source map mutated: domB password = %q, want %q", src["domB"].MachineAccountPassword, realPass)
			}
		})
	}
}

// TestMaskDomainSecretsForConnector_NonIPAdServer ensures a domain whose
// ad_server is a hostname (so net.ParseIP returns nil and no connector can be
// matched as owner) is still returned, with its secret masked.
func TestMaskDomainSecretsForConnector_NonIPAdServer(t *testing.T) {
	src := map[string]pfconfigdriver.Domain{
		"domHost": {AdServer: "ad.example.com", UseConnector: "enabled", MachineAccountPassword: "real"},
	}
	got := maskDomainSecretsForConnector(src, "connectorA", ownerLookup(nil))

	d, ok := got["domHost"]
	if !ok {
		t.Fatalf("domHost should be returned even with a hostname ad_server")
	}
	if d.MachineAccountPassword != fakeMachineAccountPassword {
		t.Errorf("domHost password = %q, want masked %q", d.MachineAccountPassword, fakeMachineAccountPassword)
	}
}

// TestStripDomainHostPrefix covers the "<host_id> <id>" -> "<id>" mapping and
// the already-raw passthrough.
func TestStripDomainHostPrefix(t *testing.T) {
	cases := map[string]string{
		"WIN-SDFCMFQ69C9 inverseINC": "inverseINC", // cloud pod hostname prefix
		"pf1.example.com domA":       "domA",        // FQDN prefix (dots)
		"packetfence-node1 domB":     "domB",        // dash in hostname
		"domA":                       "domA",        // already raw, no prefix
		"":                           "",            // empty
	}
	for in, want := range cases {
		if got := stripDomainHostPrefix(in); got != want {
			t.Errorf("stripDomainHostPrefix(%q) = %q, want %q", in, got, want)
		}
	}
}

// TestMaskDomainSecretsForConnector_StripsHostPrefix ensures the host_id
// namespace prefix is stripped from the served keys so the pfconnector-remote
// receives raw, space-free domain ids (matching pfconnector-remote-load.sh).
func TestMaskDomainSecretsForConnector_StripsHostPrefix(t *testing.T) {
	src := map[string]pfconfigdriver.Domain{
		"WIN-SDFCMFQ69C9 inverseINC": {AdServer: "10.0.0.5", UseConnector: "enabled", MachineAccountPassword: "real"},
	}
	got := maskDomainSecretsForConnector(src, "connectorA", ownerLookup(map[string]string{"10.0.0.5": "connectorA"}))

	if _, ok := got["WIN-SDFCMFQ69C9 inverseINC"]; ok {
		t.Errorf("output key should be stripped of the host_id prefix, got prefixed key %v", keys(got))
	}
	d, ok := got["inverseINC"]
	if !ok {
		t.Fatalf("expected raw key %q in output, got %v", "inverseINC", keys(got))
	}
	if d.MachineAccountPassword != "real" {
		t.Errorf("owner should get real secret, got %q", d.MachineAccountPassword)
	}
}

func keys(m map[string]pfconfigdriver.Domain) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}
