package clientapi

import (
	"os"
	"path/filepath"
	"testing"
)

func TestInstalledPackages(t *testing.T) {
	dir := t.TempDir()
	status := filepath.Join(dir, "status")
	os.WriteFile(status, []byte(`Package: packetfence-ntlm-auth-join-remote
Status: install ok installed
Priority: optional
Version: 16.0.0+1

Package: packetfence-ntlm-auth-api-remote
Status: deinstall ok config-files
Version: 15.2.0+1

Package: other
Status: install ok installed
Version: 1
`), 0o644)
	got := installedPackages(status)
	if got["packetfence-ntlm-auth-join-remote"] != "16.0.0+1" {
		t.Fatalf("join-remote: %q", got["packetfence-ntlm-auth-join-remote"])
	}
	if _, ok := got["packetfence-ntlm-auth-api-remote"]; ok {
		t.Fatalf("a removed package must not count as installed")
	}
	if installedPackages(filepath.Join(dir, "missing")) != nil {
		t.Fatalf("missing file must yield nil")
	}
}
