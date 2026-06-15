package api

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/common"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/fbcollectorclient"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
)

// collectorCaller abstracts the fingerbank collector clients so we can transparently
// use either the configured (clustered) client or a per-connector client.
type collectorCaller interface {
	Call(ctx context.Context, method, path string, payload, decodeResponseIn interface{}) error
}

func (h APIHandler) nodeFingerbankCommunications(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
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
	clientCache := map[string]collectorCaller{}
	clientForMac := map[string]collectorCaller{}
	for _, mac := range requestPayload.Nodes {
		clientForMac[mac] = h.collectorClientForMac(ctx, mac, defaultClient, connectors, clientCache)
	}

	endpoints := map[string]common.CollectorEndpointCommunications{}

	wg := sync.WaitGroup{}
	l := sync.Mutex{}
	for _, mac := range requestPayload.Nodes {
		wg.Add(1)
		go func(mac string) {
			defer wg.Done()
			ed := common.CollectorEndpointCommunications{}
			err := clientForMac[mac].Call(ctx, "GET", fmt.Sprintf("/endpoint_data/%s", mac), nil, &ed)
			if err != nil {
				log.LoggerWContext(ctx).Error("Error calling the fingerbank client: %s", err.Error())
			}
			l.Lock()
			defer l.Unlock()
			endpoints[mac] = ed
		}(mac)
	}

	wg.Wait()

	err = json.NewEncoder(w).Encode(gin.H{"items": endpoints})
	sharedutils.CheckError(err)
}

// collectorClientForMac returns the fingerbank collector client to query for a given MAC.
// When the device is behind a pfconnector (resolved from its open locationlog switch IP),
// it returns a client pointed at that connector's co-located collector. On any failure
// (no DB handle, no open session, local connector, tunnel down, etc.) it returns the
// configured (clustered) collector client.
func (h APIHandler) collectorClientForMac(ctx context.Context, mac string, defaultClient collectorCaller, connectors *connector.ConnectorsContainer, clientCache map[string]collectorCaller) collectorCaller {
	logger := log.LoggerWContext(ctx)

	switchIP := h.switchIPForMac(ctx, mac)
	if switchIP == "" {
		return defaultClient
	}

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

// switchIPForMac returns the switch IP of the device's open locationlog session, or an
// empty string when it can't be determined.
func (h APIHandler) switchIPForMac(ctx context.Context, mac string) string {
	if h.db == nil {
		return ""
	}

	var switchIP sql.NullString
	err := h.db.QueryRowContext(
		ctx,
		"SELECT switch_ip FROM locationlog WHERE mac = ? AND end_time = '0000-00-00 00:00:00' ORDER BY start_time DESC LIMIT 1",
		mac,
	).Scan(&switchIP)
	if err != nil {
		if err != sql.ErrNoRows {
			log.LoggerWContext(ctx).Debug(fmt.Sprintf("Unable to resolve switch IP for %s from locationlog: %s", mac, err))
		}
		return ""
	}
	if !switchIP.Valid {
		return ""
	}
	return switchIP.String
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
