package ldapClient

import (
	"context"
	"crypto/tls"
	"net"
	"time"

	"github.com/inverse-inc/packetfence/go/connector"
	"gopkg.in/ldap.v2"
)

type ProxyLdapClient struct {
	protocol         string
	socketAddress    string
	connectorContext context.Context
}

type ProxyLdapClientFactory struct{}

func (f ProxyLdapClientFactory) NewLdapClient(protocol string, socketAddress string, timeout time.Duration) ILdapClient {
	ldap.DefaultTimeout = timeout
	var client = &ProxyLdapClient{
		protocol:      protocol,
		socketAddress: socketAddress,
	}

	return client
}

func (c *ProxyLdapClient) Dial() (conn ILdapConnection, err error) {
	defer recoverConnectionError(conn, &err)

	addr, err := c.openProxyConnection()
	if err != nil {
		return nil, err
	}
	return ldap.Dial(c.protocol, addr)
}

func (c *ProxyLdapClient) DialTLS(config *tls.Config) (conn ILdapConnection, err error) {
	defer recoverConnectionError(conn, &err)

	addr, err := c.openProxyConnection()
	if err != nil {
		return nil, err
	}
	return ldap.DialTLS(c.protocol, addr, config)
}

func (c *ProxyLdapClient) openProxyConnection() (string, error) {
	host, port, err := net.SplitHostPort(c.socketAddress)
	if err != nil {
		return "", err
	}
	addr, err := connector.OpenConnectionTo(c.connectorContext, "tcp", host, port)
	return addr, err
}
