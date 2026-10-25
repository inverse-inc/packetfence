package main

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"sync/atomic"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// The connector scopes follow the connector configuration at runtime: a VLAN
// interface added to a connector, its DHCP turned on, its range or options
// changed, must not wait for a pfdhcp restart (which would also interrupt the
// DHCP of the local networks). The synthetic connector interface therefore
// lives outside intNametoInterface and DHCPConfig.intsNet, which are built
// once at start-up, and is swapped as a whole when the DHCP-enabled connector
// interfaces change. The pools of the rebuilt scopes are reloaded from the
// current leases (initiaLease), like at start-up.

// connectorIface is the synthetic connector interface, nil when no connector
// interface has DHCP enabled.
var connectorIface atomic.Pointer[Interface]

// connectorScopesKey is the fingerprint of the connector interfaces the
// current connectorIface was built from (start-up and watcher only).
var connectorScopesKey string

// connectorScopesRefreshInterval is how often the connector configuration is
// checked for changes.
var connectorScopesRefreshInterval = 5 * time.Second

func setConnectorInterface(i *Interface) {
	connectorIface.Store(i)
}

// lookupInterface returns the interface named name: the synthetic connector
// interface, or one of the local interfaces built at start-up.
func lookupInterface(name string) (*Interface, bool) {
	if name == ConnectorInterfaceName {
		i := connectorIface.Load()
		return i, i != nil
	}
	i, ok := intNametoInterface[name]
	return i, ok
}

// servedInterfaces returns the local interfaces and, when there is one, the
// synthetic connector interface.
func servedInterfaces() []Interface {
	if c := connectorIface.Load(); c != nil {
		return append(append([]Interface{}, DHCPConfig.intsNet...), *c)
	}
	return DHCPConfig.intsNet
}

// connectorScopesFingerprint identifies the DHCP-enabled connector interfaces
// (connector id and every field of the interface), independently of their
// order.
func connectorScopesFingerprint(connectors pfconfigdriver.Connectors) string {
	entries := []string{}
	for id, c := range connectors.Element {
		for _, ci := range c.Interfaces {
			if !sharedutils.IsEnabled(ci.Dhcp) {
				continue
			}
			b, _ := json.Marshal(ci)
			entries = append(entries, id+" "+string(b))
		}
	}
	sort.Strings(entries)
	sum := sha256.Sum256([]byte(strings.Join(entries, "\n")))
	return hex.EncodeToString(sum[:])
}

// fetchConnectors reads the connectors configuration from pfconfig.
func fetchConnectors(ctx context.Context) (pfconfigdriver.Connectors, error) {
	connectors := pfconfigdriver.Connectors{}
	err := pfconfigdriver.FetchDecodeSocket(ctx, &connectors)
	return connectors, err
}

// loadConnectorInterface builds the connector interface from connectors and
// makes it the served one.
func loadConnectorInterface(ctx context.Context, connectors pfconfigdriver.Connectors, MyDB *sql.DB, general *pfconfigdriver.PfConfGeneral, portal *pfconfigdriver.PfConfCaptivePortal) *Interface {
	iface := buildConnectorInterface(ctx, connectors, MyDB, general, portal)
	setConnectorInterface(iface)
	connectorScopesKey = connectorScopesFingerprint(connectors)
	return iface
}

// watchConnectorScopes rebuilds the connector interface whenever the
// DHCP-enabled connector interfaces change.
func watchConnectorScopes(ctx context.Context, MyDB *sql.DB) {
	ticker := time.NewTicker(connectorScopesRefreshInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
		connectors, err := fetchConnectors(ctx)
		if err != nil {
			log.LoggerWContext(ctx).Warn("Unable to fetch connectors config from pfconfig: " + err.Error())
			continue
		}
		if connectorScopesFingerprint(connectors) == connectorScopesKey {
			continue
		}
		portal := pfconfigdriver.GetType[pfconfigdriver.PfConfCaptivePortal](ctx)
		general := pfconfigdriver.GetType[pfconfigdriver.PfConfGeneral](ctx)
		iface := loadConnectorInterface(ctx, connectors, MyDB, general, portal)
		scopes := 0
		if iface != nil {
			scopes = len(iface.network)
		}
		log.LoggerWContext(ctx).Info(fmt.Sprintf("Connector configuration changed: %d connector DHCP scope(s) now served", scopes))
	}
}
