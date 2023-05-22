package pfldapexplorer

import (
	"crypto/tls"
	"time"

	"gopkg.in/ldap.v2"
)

type ILdapClient interface {
	Dial() (ILdapConnection, error)
	DialTLS(config *tls.Config) (ILdapConnection, error)
}

type ILdapConnection interface {
	Close()
	StartTLS(config *tls.Config) error
	Bind(username, password string) error
	SearchWithPaging(searchRequest *ldap.SearchRequest, pagingSize uint32) (*ldap.SearchResult, error)
}

type LdapClient struct {
	protocol      string
	socketAddress string
}

type ILdapClientFactory interface {
	NewLdapClient(protocol string, socketAddress string, timeout time.Duration) ILdapClient
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
