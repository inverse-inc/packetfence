package connector

import (
	"context"
	"fmt"
	"net"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

var mgmtipregex = regexp.MustCompile(`%mgmtip%`)

// A struct which contains all the connector IDs along with their instantiated Connectors struct
// It implements pfconfigdriver.Refreshable so that this can be part of a pfconfigdriver.Pool
type ConnectorsContainer struct {
	pfconfigdriver.CachedHash
	factory Factory
}

func NewConnectorsContainer(ctx context.Context) *ConnectorsContainer {
	cc := &ConnectorsContainer{}
	cc.PfconfigNS = "config::Connector"
	cc.factory = NewFactory(ctx)
	cc.New = func(ctx context.Context, id string) (pfconfigdriver.PfconfigObject, error) {
		return cc.factory.Instantiate(ctx, id)
	}
	cc.Refresh(ctx)
	return cc
}

func (cc *ConnectorsContainer) All(ctx context.Context) map[string]*Connector {
	connectors := map[string]*Connector{}
	for id, o := range cc.Structs {
		connectors[id] = o.(*Connector)
	}
	return connectors
}

func (cc *ConnectorsContainer) Get(ctx context.Context, id string) *Connector {
	return cc.Structs[id].(*Connector)
}

func (cc *ConnectorsContainer) ForIP(ctx context.Context, ip net.IP) *Connector {
	for _, id := range cc.Keys(ctx) {
		c := cc.Get(ctx, id)
		for _, network := range c.NetworksObjects {
			if network.Contains(ip) {
				return c
			}
		}
	}

	return cc.Get(ctx, "local_connector")
}

const connectorsContainerContextKey = "ConnectorsContainerContextKey"

func OpenConnectionTo(ctx context.Context, proto string, toIP string, toPort string, localPort string) (string, error) {
	if cc := ConnectorsContainerFromContext(ctx); cc != nil {
		keyPfConfPfDnsConnector := pfconfigdriver.PfConfPfDnsConnector{}
		keyPfConfPfDnsConnector.PfconfigNS = "config::Pf"
		keyPfConfPfDnsConnector.PfconfigHostnameOverlay = "yes"
		pfconfigdriver.FetchDecodeSocket(ctx, &keyPfConfPfDnsConnector)

		dstIp := net.ParseIP(toIP)
		if dstIp == nil {
			// probably a hostname, try to resolve it
			dnsServer := keyPfConfPfDnsConnector.PfdnsConnectorServer
			dnsServer = replaceMgmtIP(ctx, dnsServer)

			host, port, err := net.SplitHostPort(dnsServer)
			if err != nil {
				return "", err
			}
			dnsServerIP := net.ParseIP(host) // Ensure dnsServer is a valid IP address
			if dnsServer == "" {
				// If PFDNS_CONNECTOR_HOST_PORT is not set, use the default DNS server
				// This is useful in Kubernetes environments where the DNS server is set as an environment variable
				// This allows the code to work in both standalone and Kubernetes environments.
				dnsServer = os.Getenv("K8S_DNS_SERVER")
			} else if dnsServerIP == nil {
				// If PFDNS_CONNECTOR_HOST_PORT is a hostname , use the default DNS server
				// This is useful in Kubernetes environments where the DNS server is set as an environment variable
				// This allows the code to work in both standalone and Kubernetes environments.
				kubeDnsServer := os.Getenv("K8S_DNS_SERVER")
				ips, err := resolveDNSWithCustomResolver(host, kubeDnsServer)
				if err != nil {
					return "", fmt.Errorf("unable to resolve %s: %v", host, err)
				}
				if len(ips) == 0 {
					return "", fmt.Errorf("no IPs resolved for %s", host)
				}

				dstIp = net.ParseIP(ips[0])
				if dstIp == nil {
					return "", fmt.Errorf("resolved IP %s is not a valid IP address", ips[0])
				}
				dnsServer = dstIp.String() + ":" + port // Append the DNS port
			}
			ips, err := resolveDNSWithCustomResolver(toIP, dnsServer)
			if err != nil {
				return "", fmt.Errorf("unable to resolve %s: %v", toIP, err)
			}
			if len(ips) == 0 {
				return "", fmt.Errorf("no IPs resolved for %s", toIP)
			}

			dstIp = net.ParseIP(ips[0])
			if dstIp == nil {
				return "", fmt.Errorf("resolved IP %s is not a valid IP address", ips[0])
			}
			toIP = dstIp.String()
		}
		c := cc.ForIP(ctx, net.ParseIP(toIP))
		var connInfo DynReverseConnectionInfo
		var err error
		if localPort != "" {
			connInfo, err = c.DynReverseWithPort(ctx, fmt.Sprintf("%s:%s/%s", toIP, toPort, proto), localPort)
		} else {
			connInfo, err = c.DynReverse(ctx, fmt.Sprintf("%s:%s/%s", toIP, toPort, proto))
		}
		if err != nil {
			return "", fmt.Errorf("unable to obtain dynreverse for %s on port %s with proto %s", toIP, toPort, proto)
		}
		return fmt.Sprintf("%s:%s", connInfo.Host, connInfo.Port), nil
	}

	return "", fmt.Errorf("unable to find connectors container in context")
}

// Get the management IP address
func getDnsDestinationIp(ctx context.Context) net.IP {
	managementNetwork := pfconfigdriver.GetType[pfconfigdriver.ManagementNetwork](ctx)
	return net.ParseIP(managementNetwork.Ip)
}

func replaceMgmtIP(ctx context.Context, input string) string {
	match := "%mgmtip%:5353"
	if strings.Contains(input, match) {
		// Replace %mgmtip% with the management IP address
		mgmtIP := getDnsDestinationIp(ctx)
		if mgmtIP == nil {
			return "100.64.0.1:5353"
		}
		outputString := mgmtipregex.ReplaceAllString(input, mgmtIP.String())
		return outputString
	}
	return input
}

func ConnectorsContainerFromContext(ctx context.Context) *ConnectorsContainer {
	if o := ctx.Value(connectorsContainerContextKey); o != nil {
		return o.(*ConnectorsContainer)
	} else {
		return nil
	}
}

func WithConnectorsContainer(ctx context.Context, cc *ConnectorsContainer) context.Context {
	return context.WithValue(ctx, connectorsContainerContextKey, cc)
}

func resolveDNSWithCustomResolver(fqdn, dnsServer string) ([]string, error) {
	resolver := &net.Resolver{
		PreferGo: true,
		Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
			d := net.Dialer{
				Timeout: 2 * time.Second,
			}
			return d.DialContext(ctx, network, dnsServer)
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	ips, err := resolver.LookupIPAddr(ctx, fqdn)
	if err != nil {
		return nil, fmt.Errorf("error trying to resolve: %v", err)
	}

	var result []string
	for _, ip := range ips {
		if ip.IP.To4() != nil { // IPv4 seulement
			result = append(result, ip.IP.String())
		}
	}

	return result, nil
}
