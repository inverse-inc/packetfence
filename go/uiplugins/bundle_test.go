package uiplugins

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestBundleCode(t *testing.T) {
	dir := t.TempDir()
	saved := PluginsConfDir
	PluginsConfDir = dir
	defer func() { PluginsConfDir = saved }()

	code := []byte(`export default { hostApi: 1, mount () {} }`)
	sum := sha256.Sum256(code)
	write := func(name, content string) {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(content), 0644); err != nil {
			t.Fatal(err)
		}
	}
	write("kit.js", string(code))
	write("kit.conf", "[plugin]\nversion=1.0\nschema_dir=/x\n\n[bundle]\nsha256 = "+hex.EncodeToString(sum[:])+"\n")
	got, err := BundleCode("kit")
	if err != nil || string(got) != string(code) {
		t.Fatalf("a bundle matching its sha256: %q %v", got, err)
	}

	write("kit.js", string(code)+"alert(1)")
	if _, err := BundleCode("kit"); err == nil {
		t.Error("a changed bundle is served")
	}

	write("other.js", string(code))
	write("other.conf", "[plugin]\nversion=1.0\n")
	if _, err := BundleCode("other"); !errors.Is(err, ErrNoBundle) {
		t.Errorf("a descriptor without [bundle] sha256: %v", err)
	}
	if _, err := BundleCode("missing"); !errors.Is(err, ErrNoBundle) {
		t.Errorf("no descriptor: %v", err)
	}
	write("nojs.conf", "[bundle]\nsha256="+hex.EncodeToString(sum[:])+"\n")
	if _, err := BundleCode("nojs"); !errors.Is(err, ErrNoBundle) {
		t.Errorf("no code: %v", err)
	}
	if _, err := BundleCode("../kit"); err == nil {
		t.Error("a name out of the directory")
	}
}
