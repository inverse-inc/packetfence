package uiplugins

import (
	"bufio"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// PluginsConfDir holds the descriptors of the packages installed on top of
// PacketFence (<name>.conf) and the code of their bundle (<name>.js), a
// variable for the tests
var PluginsConfDir = "/usr/local/pf/conf/plugins.d"

// the size of a bundle
const maxBundleSize = 10 << 20

// ErrNoBundle is a plugin without a bundle installed on this server
var ErrNoBundle = errors.New("no bundle installed")

// descriptorBundleSHA256 reads the sha256 of the [bundle] section of a
// descriptor (conf/plugins.d/<name>.conf, pf::ui_plugins::schema reads its
// [plugin] section)
func descriptorBundleSHA256(file string) (string, error) {
	f, err := os.Open(file)
	if err != nil {
		return "", err
	}
	defer f.Close()
	section := ""
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		switch {
		case line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, ";"):
		case strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]"):
			section = strings.TrimSpace(line[1 : len(line)-1])
		case section == "bundle":
			if key, value, found := strings.Cut(line, "="); found && strings.TrimSpace(key) == "sha256" {
				return strings.ToLower(strings.TrimSpace(value)), nil
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}
	return "", nil
}

// BundleCode is the code of the bundle of a plugin: <name>.js of
// PluginsConfDir, served only when its SHA-256 is the sha256 of the [bundle]
// section of <name>.conf. The package that installs the plugin writes both;
// a plugin service only registers a host and a port, it does not serve its
// UI code. The SHA-256 detects a changed or partly written file; it does not
// prove where the file comes from: like the rest of /usr/local/pf/conf, the
// directory is writable by the pf user.
func BundleCode(name string) ([]byte, error) {
	if !nameRe.MatchString(name) {
		return nil, fmt.Errorf("invalid name %q", name)
	}
	expected, err := descriptorBundleSHA256(filepath.Join(PluginsConfDir, name+".conf"))
	if errors.Is(err, os.ErrNotExist) || (err == nil && expected == "") {
		return nil, ErrNoBundle
	}
	if err != nil {
		return nil, err
	}
	f, err := os.Open(filepath.Join(PluginsConfDir, name+".js"))
	if errors.Is(err, os.ErrNotExist) {
		return nil, ErrNoBundle
	}
	if err != nil {
		return nil, err
	}
	defer f.Close()
	code, err := io.ReadAll(io.LimitReader(f, maxBundleSize+1))
	if err != nil {
		return nil, err
	}
	if len(code) > maxBundleSize {
		return nil, fmt.Errorf("bundle larger than %d bytes", maxBundleSize)
	}
	sum := sha256.Sum256(code)
	if subtle.ConstantTimeCompare([]byte(hex.EncodeToString(sum[:])), []byte(expected)) != 1 {
		return nil, errors.New("the bundle does not match the sha256 of its descriptor")
	}
	return code, nil
}
