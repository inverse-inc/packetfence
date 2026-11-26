package ldapClient

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// TLSConfig builds the TLS configuration of an LDAP source for a session to
// serverName, the configured host. The server certificate is verified against
// that name unless the source's verify is "none", also when the session goes
// through a connector (the socket then points to the connector, not to the
// server). The CA file of the source is used when it is set and the server is
// verified (as the Perl clients, which ignore it when verify is none); the
// client certificate and key are used whenever they are set.
func TLSConfig(source pfconfigdriver.AuthenticationSourceLdap, serverName string) (*tls.Config, error) {
	verify := source.Verify != "" && source.Verify != "none"
	config := &tls.Config{ServerName: serverName, InsecureSkipVerify: !verify}
	if verify && source.CAFile != "" {
		pem, err := os.ReadFile(source.CAFile)
		if err != nil {
			return nil, fmt.Errorf("unable to read the CA file %s: %w", source.CAFile, err)
		}
		pool := x509.NewCertPool()
		if !pool.AppendCertsFromPEM(pem) {
			return nil, fmt.Errorf("no certificate found in the CA file %s", source.CAFile)
		}
		config.RootCAs = pool
	}
	if source.ClientCertFile != "" || source.ClientKeyFile != "" {
		cert, err := tls.LoadX509KeyPair(source.ClientCertFile, source.ClientKeyFile)
		if err != nil {
			return nil, fmt.Errorf("unable to load the client certificate %s and key %s: %w", source.ClientCertFile, source.ClientKeyFile, err)
		}
		config.Certificates = []tls.Certificate{cert}
	}
	return config, nil
}
