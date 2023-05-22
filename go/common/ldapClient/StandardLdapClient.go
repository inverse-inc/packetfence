package ldapClient

import (
	"crypto/tls"
	"time"

	"gopkg.in/ldap.v2"
)

type LdapClient struct {
	protocol      string
	socketAddress string
}

type LdapClientFactory struct{}

func (f LdapClientFactory) NewLdapClient(protocol string, socketAddress string, timeout time.Duration) ILdapClient {
	ldap.DefaultTimeout = timeout
	var client = &LdapClient{
		protocol:      protocol,
		socketAddress: socketAddress,
	}

	return client
}

func (c *LdapClient) Dial() (ILdapConnection, error) {
	return ldap.Dial(c.protocol, c.socketAddress)
}

func (c *LdapClient) DialTLS(config *tls.Config) (ILdapConnection, error) {
	return ldap.DialTLS(c.protocol, c.socketAddress, config)
}
