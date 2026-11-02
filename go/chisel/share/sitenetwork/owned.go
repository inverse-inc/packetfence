package sitenetwork

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/inverse-inc/go-utils/sharedutils"
)

// OwnedAddressesPath is the record of the addresses the connector assigned on
// plain (not connector-created) host interfaces, one "<link> <cidr>" per line.
// It lives next to the site-network cache in var/conf, which is bind-mounted
// from the host so it survives restarts, and is shared with
// configure-keepalived.sh (which adds the addresses it declares as virtual
// IPs) and ha-notify.sh (which releases them on a non-master host).
//
// A record file rather than an IFA_LABEL on the address: libpcap lists a
// labelled IPv4 address as a device of its own ("ens192:pf"), which the
// fingerbank-collector then fails to resolve as an interface and panics on.
var OwnedAddressesPath = sharedutils.EnvOrDefault("PFCONNECTOR_SITE_NETWORK_ADDRESSES", "/usr/local/pf/var/conf/site-network-addresses")

// ownedAddresses maps a link name to the set of CIDRs the connector owns on it.
type ownedAddresses map[string]map[string]bool

func (o ownedAddresses) has(link, cidr string) bool {
	return o[link][cidr]
}

func (o ownedAddresses) add(link, cidr string) {
	if o[link] == nil {
		o[link] = map[string]bool{}
	}
	o[link][cidr] = true
}

func (o ownedAddresses) remove(link, cidr string) {
	delete(o[link], cidr)
	if len(o[link]) == 0 {
		delete(o, link)
	}
}

func (o ownedAddresses) clone() ownedAddresses {
	out := ownedAddresses{}
	for link, cidrs := range o {
		for cidr := range cidrs {
			out.add(link, cidr)
		}
	}
	return out
}

func (o ownedAddresses) equal(other ownedAddresses) bool {
	if len(o) != len(other) {
		return false
	}
	for link, cidrs := range o {
		if len(cidrs) != len(other[link]) {
			return false
		}
		for cidr := range cidrs {
			if !other[link][cidr] {
				return false
			}
		}
	}
	return true
}

// loadOwnedAddresses reads the record at path. A missing file is an empty
// record; malformed lines are skipped.
func loadOwnedAddresses(path string) (ownedAddresses, error) {
	owned := ownedAddresses{}
	file, err := os.Open(path)
	if os.IsNotExist(err) {
		return owned, nil
	}
	if err != nil {
		return owned, err
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())
		if len(fields) != 2 || strings.HasPrefix(fields[0], "#") {
			continue
		}
		if _, _, err := net.ParseCIDR(fields[1]); err != nil {
			continue
		}
		owned.add(fields[0], fields[1])
	}
	return owned, scanner.Err()
}

// saveOwnedAddresses replaces the record at path (write to a temporary file in
// the same directory, then rename).
func saveOwnedAddresses(path string, owned ownedAddresses) error {
	lines := []string{}
	for link, cidrs := range owned {
		for cidr := range cidrs {
			lines = append(lines, link+" "+cidr)
		}
	}
	sort.Strings(lines)
	content := "# Addresses assigned by the PacketFence connector on host interfaces (<link> <cidr>); managed automatically.\n"
	if len(lines) > 0 {
		content += strings.Join(lines, "\n") + "\n"
	}
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".site-network-addresses-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.WriteString(content); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(0644); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Rename(tmp.Name(), path); err != nil {
		return fmt.Errorf("unable to replace %s: %w", path, err)
	}
	return nil
}
