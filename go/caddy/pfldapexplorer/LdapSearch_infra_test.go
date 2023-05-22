package pfldapexplorer_test

import (
	"crypto/tls"
	"encoding/json"
	"time"

	"gopkg.in/ldap.v2"

	"github.com/inverse-inc/packetfence/go/caddy/pfldapexplorer"
)

type SpyLdapClient struct {
	DialCallCount    int
	DialTLSCallCount int
}

var DialResponse pfldapexplorer.ILdapConnection
var DialError error

func (c *SpyLdapClient) DialTLS(config *tls.Config) (pfldapexplorer.ILdapConnection, error) {
	c.DialTLSCallCount++
	return DialResponse, DialError
}

func (c *SpyLdapClient) Dial() (pfldapexplorer.ILdapConnection, error) {
	c.DialCallCount++
	return DialResponse, DialError
}

type MockLdapClientFactory struct {
	SocketAddressUsed string
	ProtocolUsed      string
	TimeoutUsed       time.Duration
	LdapClientSpy     *SpyLdapClient
}

func (f *MockLdapClientFactory) NewLdapClient(protocol string, socketAddress string, timeout time.Duration) pfldapexplorer.ILdapClient {
	f.SocketAddressUsed = socketAddress
	f.ProtocolUsed = protocol
	f.TimeoutUsed = timeout
	ldap.DefaultTimeout = timeout
	return f.LdapClientSpy
}

type ConnectionSpy struct {
	CloseCalled bool
	response    ldap.SearchResult
	err         error
	startTlsErr error
	bindErr     error
}

func (c *ConnectionSpy) Close() {
	c.CloseCalled = true
}

func (c *ConnectionSpy) StartTLS(config *tls.Config) error {
	return c.startTlsErr
}

func (c *ConnectionSpy) Bind(username, password string) error {
	return c.bindErr
}

func (c *ConnectionSpy) SearchWithPaging(searchRequest *ldap.SearchRequest, pagingSize uint32) (*ldap.SearchResult, error) {
	return &c.response, c.err
}

var OpenLdapResponse = `{
					"Entries": [
					{
						"DN": "uid=test_human,ou=people,dc=ip,dc=linodeusercontent,dc=com",
						"Attributes": [
						{
							"Name": "cn",
							"Values": [
							"test_human"
							],
							"ByteValues": [
							"dGVzdF9odW1hbg=="
							]
						},
						{
							"Name": "gidNumber",
							"Values": [
							"123"
							],
							"ByteValues": [
							"MTIz"
							]
						},
						{
							"Name": "homeDirectory",
							"Values": [
							"/home/human"
							],
							"ByteValues": [
							"L2hvbWUvaHVtYW4="
							]
						},
						{
							"Name": "objectClass",
							"Values": [
							"inetOrgPerson",
							"organizationalPerson",
							"person",
							"posixAccount",
							"shadowAccount",
							"top"
							],
							"BnyteValues": [
							"aW5ldE9yZ1BlcnNvbg==",
							"b3JnYW5pemF0aW9uYWxQZXJzb24=",
							"cGVyc29u",
							"cG9zaXhBY2NvdW50",
							"c2hhZG93QWNjb3VudA==",
							"dG9w"
							]
						},
						{
							"Name": "sn",
							"Values": [
							"test_human"
							],
							"ByteValues": [
							"dGVzdF9odW1hbg=="
							]
						},
						{
							"Name": "uid",
							"Values": [
							"test_human"
							],
							"ByteValues": [
							"dGVzdF9odW1hbg=="
							]
						},
						{
							"Name": "uidNumber",
							"Values": [
							"123"
							],
							"ByteValues": [
							"MTIz"
							]
						},
						{
							"Name": "description",
							"Values": [
							"It's a real human bean. I prommise"
							],
							"ByteValues": [
							"SXQncyBhIHJlYWwgaHVtYW4gYmVhbi4gSSBwcm9tbWlzZQ=="
							]
						}
						]
					}
					],
					"Referrals": null,
					"Controls": [
					{
						"PagingSize": 0,
						"Cookie": null
					}
					]
				}`

var OpenLdapResponseParsed = map[string]map[string]interface{}{
	"uid=test_human,ou=people,dc=ip,dc=linodeusercontent,dc=com": {"cn": "test_human",
		"gidNumber":     "123",
		"homeDirectory": "/home/human",
		"objectClass":   []string{"inetOrgPerson", "organizationalPerson", "person", "posixAccount", "shadowAccount", "top"},
		"sn":            "test_human",
		"uid":           "test_human",
		"uidNumber":     "123",
		"description":   "It's a real human bean. I prommise"}}

func GetLdapSearchResponse(responseInJson string) ldap.SearchResult {
	var ldapSearchResponse ldap.SearchResult
	json.Unmarshal([]byte(responseInJson), &ldapSearchResponse)
	return ldapSearchResponse
}
