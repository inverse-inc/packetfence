package api

import (
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/miekg/dns"
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
			Mode           string `json:"mode"`
		}{}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			http.Error(w, "Cannot parse request body", http.StatusBadRequest)
			return
		}
		if payload.Name == "" {
			http.Error(w, "name is required", http.StatusBadRequest)
			return
		}
		if payload.Type == "" {
			payload.Type = "A"
		}
		if payload.Mode == "" {
			payload.Mode = "tunnel"
		}
		// The pfdns-connector front-end routes by queried domain, so
		// packetfence mode needs no dns_connector_id; tunnel mode targets
		// one entry's tunnel and does.
		if payload.Mode != "packetfence" && payload.DnsConnectorID == "" {
			http.Error(w, "dns_connector_id is required", http.StatusBadRequest)
			return
		}

		// "packetfence" mode: resolve exactly as PacketFence does at
		// runtime, through the pfdns-connector front-end
		// (pfdns_connector_server), catching forwarder-level misrouting the
		// direct tunnel test cannot see.
		if payload.Mode == "packetfence" {
			resolver, err := connector.PfdnsConnectorServerAddr(h.ctx)
			if err != nil {
				log.LoggerWContext(r.Context()).Error(fmt.Sprintf("Unable to resolve pfdns_connector_server: %s", err))
				http.Error(w, "Unable to resolve the pfdns-connector front-end address", http.StatusBadGateway)
				return
			}
			lookup := dnsQuery(resolver, payload.Name, payload.Type)
			dnsConnectorID := payload.DnsConnectorID
			if dnsConnectorID == "" {
				dnsConnectorID = "-"
			}
			reply := map[string]interface{}{
				"mode":             payload.Mode,
				"dns_connector_id": dnsConnectorID,
				"dns_server":       resolver,
				"pfconnector_port": "-",
				"connector_id":     "pfdns-connector",
				"name":             payload.Name,
				"type":             payload.Type,
			}
			for k, v := range lookup {
				reply[k] = v
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			json.NewEncoder(w).Encode(reply)
			return
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
			"mode":             payload.Mode,
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

// dnsQuery sends one DNS query to server ("ip:port") and returns the result
// in the same shape as the chisel server's /dns-lookup endpoint.
func dnsQuery(server, name, qtypeStr string) map[string]interface{} {
	out := map[string]interface{}{
		"reachable":  false,
		"rcode":      "",
		"latency_ms": int64(0),
		"answers":    []string{},
	}
	qtype, ok := dns.StringToType[strings.ToUpper(qtypeStr)]
	if !ok {
		out["error"] = "Invalid DNS record type"
		return out
	}

	m := new(dns.Msg)
	m.SetQuestion(dns.Fqdn(name), qtype)
	m.RecursionDesired = true

	client := &dns.Client{Timeout: 5 * time.Second}
	start := time.Now()
	in, _, err := client.Exchange(m, server)
	out["latency_ms"] = time.Since(start).Milliseconds()
	if err != nil {
		out["error"] = err.Error()
		return out
	}
	out["reachable"] = true
	out["rcode"] = dns.RcodeToString[in.Rcode]
	answers := make([]string, 0, len(in.Answer))
	for _, rr := range in.Answer {
		answers = append(answers, rr.String())
	}
	out["answers"] = answers
	return out
}
