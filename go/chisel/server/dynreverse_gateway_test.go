package chserver

import "testing"

// The containers gateway listener is only added for classic containers on a
// bridge network.
func TestDynReverseGatewayHost(t *testing.T) {
	t.Setenv("PFCONNECTOR_SERVER_DYN_REVERSE_GATEWAY", "100.64.0.1")
	t.Setenv("IS_A_CLASSIC_PF_CONTAINER", "")
	t.Setenv("DOCKER_NETWORK_IS_HOST", "")
	if got := dynReverseGatewayHost(); got != "" {
		t.Errorf("not a classic container: %q", got)
	}
	t.Setenv("IS_A_CLASSIC_PF_CONTAINER", "yes")
	if got := dynReverseGatewayHost(); got != "100.64.0.1" {
		t.Errorf("classic container: %q", got)
	}
	t.Setenv("DOCKER_NETWORK_IS_HOST", "yes")
	if got := dynReverseGatewayHost(); got != "" {
		t.Errorf("host network: %q", got)
	}
	t.Setenv("DOCKER_NETWORK_IS_HOST", "")
	t.Setenv("PFCONNECTOR_SERVER_DYN_REVERSE_GATEWAY", "2001:db8::1")
	if got := dynReverseGatewayHost(); got != "" {
		t.Errorf("IPv6 gateway: %q", got)
	}
}
