package api

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/common"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/fbcollectorclient"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// collectorCaller abstracts the fingerbank collector clients so we can transparently
// use either the configured (clustered) client or a per-connector client.
type collectorCaller interface {
	Call(ctx context.Context, method, path string, payload, decodeResponseIn interface{}) error
}

func (h *APIHandler) nodeFingerbankCommunications() http.HandlerFunc {

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		defaultClient := pfconfigdriver.GetRefresh(ctx, "fbcollectorclient").(*fbcollectorclient.ClientFromConfig)
		requestPayload := struct {
			Nodes []string
		}{}

		defer r.Body.Close()
		err := json.NewDecoder(r.Body).Decode(&requestPayload)
		sharedutils.CheckError(err)

		// Resolve the collector client to use for each MAC. Devices behind a pfconnector are
		// queried only on the collector co-located with that connector instead of fanning out
		// across all collectors. Anything that can't be resolved falls back to the configured
		// (clustered) collector. Clients are cached per connector id to avoid redundant lookups.
		connectors := connector.NewConnectorsContainer(ctx)
		switchIPs := map[string]string{}
		if connectors.HasRemoteConnectors(ctx) {
			switchIPs = h.switchIPsForMacs(ctx, requestPayload.Nodes)
		}

		clientCache := map[string]collectorCaller{}
		clientForMac := map[string]collectorCaller{}
		for _, mac := range requestPayload.Nodes {
			clientForMac[mac] = collectorClientForSwitchIP(ctx, switchIPs[normalizeMac(mac)], defaultClient, connectors, clientCache)
		}

		endpoints := map[string]common.CollectorEndpointCommunications{}

		wg := sync.WaitGroup{}
		l := sync.Mutex{}
		for _, mac := range requestPayload.Nodes {
			wg.Add(1)
			go func(mac string) {
				defer wg.Done()
				ed, err := fetchEndpointData(ctx, mac, clientForMac[mac], defaultClient)
				if err != nil {
					log.LoggerWContext(ctx).Error(fmt.Sprintf("Error calling the fingerbank client: %s", err.Error()))
				}
				l.Lock()
				defer l.Unlock()
				endpoints[mac] = ed
			}(mac)
		}

		wg.Wait()

		err = json.NewEncoder(w).Encode(gin.H{"items": endpoints})
		sharedutils.CheckError(err)
	})
}

// fetchEndpointData queries the endpoint data of a MAC on its resolved collector. A
// dedicated (per-connector) collector can fail after it was resolved, e.g. when the
// tunnel drops mid-request, so a failure there is retried once on the configured collector.
func fetchEndpointData(ctx context.Context, mac string, client, defaultClient collectorCaller) (common.CollectorEndpointCommunications, error) {
	path := fmt.Sprintf("/endpoint_data/%s", mac)
	ed := common.CollectorEndpointCommunications{}
	err := client.Call(ctx, "GET", path, nil, &ed)
	if err == nil || client == defaultClient {
		return ed, err
	}

	log.LoggerWContext(ctx).Warn(fmt.Sprintf("Dedicated fingerbank collector failed for %s, retrying on the configured collector: %s", mac, err))
	ed = common.CollectorEndpointCommunications{}
	err = defaultClient.Call(ctx, "GET", path, nil, &ed)
	return ed, err
}

// collectorClientForSwitchIP returns the fingerbank collector client to query for a
// device whose open locationlog session is on switchIP. When that switch is behind a
// pfconnector, it returns a client pointed at that connector's co-located collector. On
// any failure (no open session, local connector, tunnel down, etc.) it returns the
// configured (clustered) collector client.
func collectorClientForSwitchIP(ctx context.Context, switchIP string, defaultClient collectorCaller, connectors *connector.ConnectorsContainer, clientCache map[string]collectorCaller) collectorCaller {
	logger := log.LoggerWContext(ctx)

	ip := net.ParseIP(switchIP)
	if ip == nil {
		return defaultClient
	}

	conn := connectors.ForIP(ctx, ip)
	if conn == nil || conn.PfconfigHashNS == "" || conn.PfconfigHashNS == "local_connector" {
		return defaultClient
	}

	connectorID := conn.PfconfigHashNS
	if cached, ok := clientCache[connectorID]; ok {
		return cached
	}

	endpoint, err := conn.FingerbankCollectorEndpoint(ctx)
	if err != nil || endpoint == "" {
		logger.Debug(fmt.Sprintf("Unable to obtain a dedicated fingerbank collector endpoint for connector '%s', falling back to the configured collector: %v", connectorID, err))
		clientCache[connectorID] = defaultClient
		return defaultClient
	}

	client := buildCollectorClientFromEndpoint(ctx, endpoint)
	if client == nil {
		clientCache[connectorID] = defaultClient
		return defaultClient
	}

	logger.Debug(fmt.Sprintf("Using dedicated fingerbank collector %s for connector '%s'", endpoint, connectorID))
	clientCache[connectorID] = client
	return client
}

// normalizeMac returns mac in the lowercase colon-separated form the locationlog
// stores, or an empty string when it isn't a MAC address.
func normalizeMac(mac string) string {
	hw, err := net.ParseMAC(mac)
	if err != nil || len(hw) != 6 {
		return ""
	}
	return hw.String()
}

// switchIPsForMacs returns, keyed by normalized MAC, the switch IP of each device's
// open locationlog session, read in a single query. Devices without one are absent.
func (h *APIHandler) switchIPsForMacs(ctx context.Context, macs []string) map[string]string {
	switchIPs := map[string]string{}
	if h.db == nil {
		return switchIPs
	}

	args := []interface{}{}
	for _, mac := range macs {
		if mac = normalizeMac(mac); mac != "" {
			args = append(args, mac)
		}
	}
	if len(args) == 0 {
		return switchIPs
	}

	// Rows come oldest session first so the most recent open one wins.
	rows, err := h.db.QueryContext(
		ctx,
		"SELECT mac, switch_ip FROM locationlog WHERE mac IN (?"+strings.Repeat(",?", len(args)-1)+") AND end_time = '0000-00-00 00:00:00' ORDER BY start_time",
		args...,
	)
	if err != nil {
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Unable to resolve switch IPs from locationlog: %s", err))
		return switchIPs
	}
	defer rows.Close()

	for rows.Next() {
		var mac string
		var switchIP sql.NullString
		if err := rows.Scan(&mac, &switchIP); err != nil {
			log.LoggerWContext(ctx).Debug(fmt.Sprintf("Unable to read a locationlog switch IP: %s", err))
			continue
		}
		if switchIP.Valid && switchIP.String != "" {
			switchIPs[mac] = switchIP.String
		}
	}
	if err := rows.Err(); err != nil {
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Unable to read the locationlog switch IPs: %s", err))
	}

	return switchIPs
}

// buildCollectorClientFromEndpoint builds a fingerbank collector client targeting the
// given endpoint URL, reusing the configured API key. Returns nil on a malformed URL.
func buildCollectorClientFromEndpoint(ctx context.Context, endpoint string) collectorCaller {
	u, err := url.Parse(endpoint)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Unable to parse fingerbank collector endpoint '%s': %s", endpoint, err))
		return nil
	}

	conf := pfconfigdriver.FingerbankSettings{}
	pfconfigdriver.FetchDecodeSocketCache(ctx, &conf)

	return fbcollectorclient.New(
		ctx,
		conf.Upstream.ApiKey,
		u.Scheme,
		u.Hostname(),
		u.Port(),
		fbcollectorclient.ProxyURL(ctx, conf.Proxy),
	)
}
