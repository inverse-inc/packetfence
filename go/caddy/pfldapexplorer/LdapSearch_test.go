package pfldapexplorer_test

import (
	"errors"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/inverse-inc/packetfence/go/caddy/pfldapexplorer"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

var _ = Describe("LdapSearch", func() {
	var searchQuery *pfldapexplorer.SearchQuery
	var ldapServer *pfldapexplorer.LdapServer

	Describe("SearchLdap", func() {
		Context("when no servers can be reached", func() {
			var ldapClientSpy *SpyLdapClient
			var factory pfldapexplorer.ILdapClientFactory
			var ldapSearchClient pfldapexplorer.LdapSearchClient

			BeforeEach(func() {
				ldapClientSpy = &SpyLdapClient{
					DialCallCount:    0,
					DialTLSCallCount: 0,
				}
				factory = &MockLdapClientFactory{LdapClientSpy: ldapClientSpy}
				DialResponse = nil
				DialError = errors.New("fake error")
				searchQuery = &pfldapexplorer.SearchQuery{
					Server:     "fake_configured_server",
					Search:     "(uid=test_human)",
					Attributes: []string{"userPrincipalName"},
				}
				ldapServer = &pfldapexplorer.LdapServer{
					AuthenticationSourceLdap: pfconfigdriver.AuthenticationSourceLdap{
						Host:           []string{"1.1.1.1", "localhost", "2.2.2.2"},
						PfconfigNS:     "fake_pfconfig_ns",
						PfconfigHashNS: "fake_pfconfig_hash_ns",
					},
				}
				ldapSearchClient = pfldapexplorer.LdapSearchClient{
					LdapServer:        ldapServer,
					Timeout:           time.Duration(0),
					LdapClientFactory: factory,
				}
			})

			It("should call DialTLS and fail", func() {
				ldapServer.Encryption = "ssl"
				serverCount := len(ldapServer.AuthenticationSourceLdap.Host)

				results, err := ldapSearchClient.SearchLdap(searchQuery)

				Expect(results).To(BeNil())
				Expect(err).ToNot(BeNil())
				Expect(ldapClientSpy.DialCallCount).To(Equal(0))
				Expect(ldapClientSpy.DialTLSCallCount).To(Equal(serverCount))
			})

			It("should call Dial and fail", func() {
				ldapServer.Encryption = "starttls"
				serverCount := len(ldapServer.AuthenticationSourceLdap.Host)

				results, err := ldapSearchClient.SearchLdap(searchQuery)

				Expect(results).To(BeNil())
				Expect(err).ToNot(BeNil())
				Expect(ldapClientSpy.DialCallCount).To(Equal(serverCount))
				Expect(ldapClientSpy.DialTLSCallCount).To(Equal(0))
			})

			It("should call ldap client factory", func() {
				ldapServer.Host = []string{"fakeHostname"}
				ldapServer.Port = "389"
				factory := &MockLdapClientFactory{LdapClientSpy: ldapClientSpy}
				ldapSearchClient = pfldapexplorer.LdapSearchClient{
					LdapServer:        ldapServer,
					Timeout:           time.Duration(5),
					LdapClientFactory: factory,
				}

				ldapSearchClient.SearchLdap(searchQuery)

				Expect(factory.TimeoutUsed).To(Equal(time.Duration(5)))
				Expect(factory.ProtocolUsed).To(Equal("tcp"))
				Expect(factory.SocketAddressUsed).To(Equal("fakeHostname:389"))
			})

		})

		Context("when connection is established", func() {
			var ldapSeachClient pfldapexplorer.LdapSearchClient
			var connection *ConnectionSpy

			BeforeEach(func() {
				connection = &ConnectionSpy{
					CloseCalled: false,
					response:    GetLdapSearchResponse(OpenLdapResponse),
				}
				DialResponse = connection
				DialError = nil
				searchQuery = &pfldapexplorer.SearchQuery{}
				ldapServer = &pfldapexplorer.LdapServer{
					AuthenticationSourceLdap: pfconfigdriver.AuthenticationSourceLdap{
						Host:           []string{"localhost"},
						PfconfigNS:     "fake_pfconfig_ns",
						PfconfigHashNS: "fake_pfconfig_hash_ns",
						Scope:          "sub",
					},
				}
				ldapClientSpy := SpyLdapClient{}
				factory := &MockLdapClientFactory{LdapClientSpy: &ldapClientSpy}
				ldapSeachClient = pfldapexplorer.LdapSearchClient{
					LdapServer:        ldapServer,
					LdapClientFactory: factory,
				}
			})

			It("should parse the response", func() {

				searchResults, err := ldapSeachClient.SearchLdap(searchQuery)

				Expect(searchResults).To(Equal(OpenLdapResponseParsed))
				Expect(err).To(BeNil())
			})

			It("should close the connection", func() {

				ldapSeachClient.SearchLdap(searchQuery)

				Expect(connection.CloseCalled).To(BeTrue())
			})

			Context("but failed reconnecting to TLS", func() {
				BeforeEach(func() {
					connection.startTlsErr = errors.New("fake error")
					ldapServer.Encryption = "starttls"
				})
				It("should return an error", func() {

					searchResults, err := ldapSeachClient.SearchLdap(searchQuery)

					Expect(searchResults).To(BeNil())
					Expect(err).ToNot(BeNil())
				})
				It("should close the connection", func() {

					ldapSeachClient.SearchLdap(searchQuery)

					Expect(connection.CloseCalled).To(BeTrue())
				})
			})

			Context("but failed to authenticate", func() {
				BeforeEach(func() {
					connection.bindErr = errors.New("fake error")
				})
				It("should return an error", func() {

					searchResults, err := ldapSeachClient.SearchLdap(searchQuery)

					Expect(searchResults).To(BeNil())
					Expect(err).ToNot(BeNil())
				})
				It("should close the connection", func() {

					ldapSeachClient.SearchLdap(searchQuery)

					Expect(connection.CloseCalled).To(BeTrue())
				})
			})

			Context("when search fails", func() {
				It("should return an error", func() {
					connection.err = errors.New("fake error")

					searchResults, err := ldapSeachClient.SearchLdap(searchQuery)

					Expect(searchResults).To(BeNil())
					Expect(err).ToNot(BeNil())
				})
			})
		})
	})
})
