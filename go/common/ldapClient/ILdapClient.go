package ldapClient

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
	Search(searchRequest *ldap.SearchRequest) (*ldap.SearchResult, error)
}

type ILdapClientFactory interface {
	NewLdapClient(protocol string, socketAddress string, timeout time.Duration) ILdapClient
}
