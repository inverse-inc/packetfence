package pfldapexplorer

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"gopkg.in/ldap.v2"
)

type SearchQuery struct {
	Server     string   `json:"server"`
	Search     string   `json:"search"`
	Attributes []string `json:"attributes,omitempty"`
}

func SearchLdap(query *SearchQuery, ldapServer *ldapServer, timeout time.Duration) (map[string]map[string]interface{}, error) {
	conn := connect(ldapServer, timeout)
	if conn == nil {
		return nil, errors.New("failed to connect to the LDAP server")
	}

	defer conn.Close()

	scope, ok := scopes[ldapServer.Scope]

	if !ok {
		return nil, errors.New("unknown search scope: " + ldapServer.Scope)
	}

	response, err := conn.SearchWithPaging(&ldap.SearchRequest{
		BaseDN:     ldapServer.BaseDN,
		Scope:      scope,
		Filter:     query.Search,
		Attributes: query.Attributes,
	}, uint32(200))

	if err != nil {
		return nil, errors.New("failed search: " + err.Error())
	}

	_, err = json.MarshalIndent(transform(response.Entries), "", "  ")
	if err != nil {
		return nil, errors.New("cannot unmarshall: " + err.Error())
	}

	return transform(response.Entries), nil
}

func connect(ldapServer *ldapServer, timeout time.Duration) *ldap.Conn {
	ldap.DefaultTimeout = timeout
	ctx := log.LoggerNewContext(context.Background())
	sources := ldapServer.Host
	sslEnabled := ldapServer.Encryption == "ssl"
	tlsEnabled := ldapServer.Encryption == "starttls"

	for _, src := range sources {
		serverSocketAddress := fmt.Sprintf("%s:%s", src, ldapServer.Port)
		conn, err := checkConnection(serverSocketAddress, sslEnabled)

		if err != nil {
			log.LogInfo(ctx, "Failed to connect to the LDAP server: "+err.Error())
			continue
		}

		if tlsEnabled {
			err = conn.StartTLS(&tls.Config{InsecureSkipVerify: true})
		}

		if err != nil {
			log.LogInfo(ctx, "Failed to re-connect to an LDAP server using TLS: "+err.Error())
			continue
		}

		if err = conn.Bind(ldapServer.BindDN, ldapServer.Password); err != nil {
			log.LogInfo(ctx, "Failed to authenticate to an LDAP server: "+err.Error())
			continue
		}

		return conn
	}

	return nil
}

func checkConnection(serverSocketAddress string, sslEnabled bool) (conn *ldap.Conn, err error) {
	if sslEnabled {
		conn, err = ldap.DialTLS("tcp", serverSocketAddress, &tls.Config{
			InsecureSkipVerify: true,
		})
	} else {
		conn, err = ldap.Dial("tcp", serverSocketAddress)
	}
	return conn, err
}

func transform(entries []*ldap.Entry) map[string]map[string]interface{} {
	res := make(map[string]map[string]interface{})
	for _, entry := range entries {
		res[entry.DN] = transformAttribs(entry.Attributes)
	}
	return res
}

func transformAttribs(attribs []*ldap.EntryAttribute) map[string]interface{} {
	res := make(map[string]interface{})
	for _, attrib := range attribs {
		switch len(attrib.Values) {
		case 0:
			res[attrib.Name] = nil
		case 1:
			res[attrib.Name] = attrib.Values[0]
		default:
			res[attrib.Name] = attrib.Values
		}
	}
	return res
}
