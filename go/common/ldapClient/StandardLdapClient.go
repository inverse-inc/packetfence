package ldapClient

import (
	"crypto/tls"
	"fmt"
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

func recoverConnectionError(ldapConnection ILdapConnection, err *error) {
	if r := recover(); r != nil {
		ldapConnection = nil
		*err = fmt.Errorf("failed to connect to the LDAP server: %v", r)
	}
}

func (c *LdapClient) Dial() (conn ILdapConnection, err error) {
	defer recoverConnectionError(conn, &err)

	return ldap.Dial(c.protocol, c.socketAddress)
}

func (c *LdapClient) DialTLS(config *tls.Config) (conn ILdapConnection, err error) {
	defer recoverConnectionError(conn, &err)

	return ldap.DialTLS(c.protocol, c.socketAddress, config)
}
