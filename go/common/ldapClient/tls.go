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
// server). The CA file and the client certificate and key of the source are
// used when they are set.
func TLSConfig(source pfconfigdriver.AuthenticationSourceLdap, serverName string) (*tls.Config, error) {
	config := &tls.Config{ServerName: serverName}
	if source.Verify == "" || source.Verify == "none" {
		config.InsecureSkipVerify = true
	}
	if source.CAFile != "" {
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
