package acme

import (
	"errors"
	"fmt"
	"net"
	"strings"
	"unicode"
)

// maxIdentifierLen matches pki_acme_authzs.value (varchar(255)).
const maxIdentifierLen = 255

// validateIdentifier checks an RFC 8555 §9.7.7 identifier before an
// order is created. The value ends up in a URL the server fetches
// (http-01) and in the CN of a certificate we sign, so it is treated as
// hostile input: only well-formed values of the types we can actually
// challenge are accepted.
func validateIdentifier(typ, value string) error {
	v := strings.TrimSpace(value)
	if v == "" {
		return errors.New("identifier value is empty")
	}
	if len(v) > maxIdentifierLen {
		return fmt.Errorf("identifier value longer than %d characters", maxIdentifierLen)
	}
	switch typ {
	case "dns":
		return validateDNSIdentifier(v)
	case "ip":
		ip := net.ParseIP(v)
		if ip == nil {
			return fmt.Errorf("identifier %q is not an IP address", v)
		}
		if !http01AllowedIP(ip) {
			return fmt.Errorf("identifier %q is not a routable unicast address", v)
		}
		return nil
	case "permanent-identifier":
		for _, r := range v {
			if r > unicode.MaxASCII || !unicode.IsPrint(r) {
				return errors.New("permanent-identifier must be printable ASCII")
			}
		}
		return nil
	default:
		// "email" (RFC 8823) can be listed on the profile for later, but
		// no challenge type exists for it yet: the only challenge we
		// would seed is http-01, which would treat the address as a host
		// name. Refuse rather than fetch http://user@host/.
		return fmt.Errorf("identifier type %q has no supported challenge", typ)
	}
}

// validateDNSIdentifier accepts a host name per RFC 1123 (letters,
// digits, hyphens; labels of 1-63 characters; no empty labels) and
// nothing else: no scheme, port, path, userinfo, wildcard or IP
// literal. Case is not significant; the CSR check uses EqualFold.
func validateDNSIdentifier(v string) error {
	if len(v) > 253 {
		return fmt.Errorf("identifier %q is too long for a DNS name", v)
	}
	if strings.HasPrefix(v, "*.") {
		return fmt.Errorf("wildcard identifier %q is not supported", v)
	}
	if net.ParseIP(v) != nil {
		return fmt.Errorf("identifier %q is an IP address, use type ip", v)
	}
	for _, l := range strings.Split(strings.TrimSuffix(v, "."), ".") {
		if l == "" || len(l) > 63 || l[0] == '-' || l[len(l)-1] == '-' {
			return fmt.Errorf("identifier %q is not a valid DNS name", v)
		}
		for i := 0; i < len(l); i++ {
			c := l[i]
			if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '-') {
				return fmt.Errorf("identifier %q is not a valid DNS name", v)
			}
		}
	}
	return nil
}
