package api

import (
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// pfconnectorDnsLookup performs a DNS query through the tunnel of a DNS
// connector entry: it resolves the entry to the connector owning the DNS
// server's IP, then asks the pfconnector server holding that tunnel to query
// its local bind (the entry's pfconnector_port). Any DNS answer, NXDOMAIN
// included, proves the whole path works.
func (h APIHandler) pfconnectorDnsLookup() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		payload := struct {
			DnsConnectorID string `json:"dns_connector_id"`
			Name           string `json:"name"`
			Type           string `json:"type"`
		}{}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			http.Error(w, "Cannot parse request body", http.StatusBadRequest)
			return
		}
		if payload.DnsConnectorID == "" || payload.Name == "" {
			http.Error(w, "dns_connector_id and name are required", http.StatusBadRequest)
			return
		}
		if payload.Type == "" {
			payload.Type = "A"
		}

		dnsConnectors := pfconfigdriver.PfConfDnsConnectors{}
		if err := pfconfigdriver.FetchDecodeSocket(r.Context(), &dnsConnectors); err != nil {
			http.Error(w, "Unable to fetch DNS connectors configuration", http.StatusInternalServerError)
			return
		}
		entryRaw, found := dnsConnectors.Element[payload.DnsConnectorID]
		if !found {
			http.Error(w, "Unknown DNS connector", http.StatusNotFound)
			return
		}
		entry, _ := entryRaw.(map[string]interface{})
		entryStr := func(key string) string {
			if v, ok := entry[key].(string); ok {
				return v
			}
			return ""
		}
		dnsIP := entryStr("ip")
		pfconnectorPort := entryStr("pfconnector_port")
		if dnsIP == "" || pfconnectorPort == "" {
			http.Error(w, "DNS connector entry has no ip or pfconnector_port", http.StatusUnprocessableEntity)
			return
		}

		// The connector owning the DNS server's IP holds the static tunnel
		// (same logic as resource::pfconnector_static_connections)
		conn := connector.NewConnectorsContainer(h.ctx).ForIP(h.ctx, net.ParseIP(dnsIP))
		if conn == nil {
			http.Error(w, "No connector (not even local_connector) matches the DNS server IP", http.StatusUnprocessableEntity)
			return
		}

		lookup := map[string]interface{}{}
		path := fmt.Sprintf("/api/v1/pfconnector/dns-lookup?port=%s&name=%s&type=%s",
			url.QueryEscape(pfconnectorPort), url.QueryEscape(payload.Name), url.QueryEscape(payload.Type))
		if err := conn.ServerCall(r.Context(), "GET", path, &lookup); err != nil {
			log.LoggerWContext(r.Context()).Error(fmt.Sprintf("DNS lookup through connector %s failed: %s", conn.PfconfigHashNS, err))
			http.Error(w, "Unable to reach the pfconnector server for this connector", http.StatusBadGateway)
			return
		}

		reply := map[string]interface{}{
			"dns_connector_id": payload.DnsConnectorID,
			"dns_server":       dnsIP + ":" + entryStr("port"),
			"pfconnector_port": pfconnectorPort,
			"connector_id":     conn.PfconfigHashNS,
			"name":             payload.Name,
			"type":             payload.Type,
		}
		for k, v := range lookup {
			reply[k] = v
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(reply)
	})
}
