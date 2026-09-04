package main

import (
	"context"
	"database/sql"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/gorilla/mux"
	dhcp "github.com/inverse-inc/dhcp4"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/api-frontend/unifiedapierrors"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type API struct {
	DB  *sql.DB
	Ctx context.Context
}

// Node struct
type Node struct {
	Mac    string    `json:"mac"`
	IP     string    `json:"ip"`
	Pool   string    `json:"pool"`
	Error  string    `json:"error"`
	EndsAt time.Time `json:"ends_at"`
}

// Stats struct
type Stats struct {
	EthernetName     string            `json:"interface"`
	Net              string            `json:"network"`
	Free             int               `json:"free"`
	PercentFree      int               `json:"percentfree"`
	Used             int               `json:"used"`
	PercentUsed      int               `json:"percentused"`
	Category         string            `json:"category"`
	Options          map[string]string `json:"options"`
	Members          []Node            `json:"members"`
	Status           string            `json:"status"`
	Size             int               `json:"size"`
	InPoolNotInCache []string          `json:"inPoolNotInCache"`
	DuplicateInPool  map[string]string `json:"DuplicateInPool"`
}

// Items struct
type Items struct {
	Items  []Stats `json:"items"`
	Status string  `json:"status"`
}

// APIReq struct
type APIReq struct {
	Req          string
	NetInterface string
	NetWork      string
	Mac          string
	Role         string
}

// Options Struct
type Options struct {
	Option dhcp.OptionCode `json:"option"`
	Value  string          `json:"value"`
	Type   string          `json:"type"`
}

// Info struct
type Info struct {
	Status  string `json:"status"`
	Mac     string `json:"mac,omitempty"`
	Network string `json:"network,omitempty"`
}

// OptionsFromFilter struct
type OptionsFromFilter struct {
	Option dhcp.OptionCode `json:"option"`
	Type   string          `json:"type"`
}

func (a *API) handleIP2Mac(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if index, expiresAt, found := GlobalIPCache.GetWithExpiration(vars["ip"]); found {
		var node = &Node{Mac: index.(string), IP: vars["ip"], EndsAt: expiresAt}

		outgoingJSON, err := json.Marshal(node)

		if err != nil {
			unifiedapierrors.Error(res, err.Error(), http.StatusInternalServerError)
			return
		}

		fmt.Fprint(res, string(outgoingJSON))
		return
	}
	unifiedapierrors.Error(res, "Cannot find match for this IP address", http.StatusNotFound)
	return
}

func (a *API) handleMac2Ip(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if index, expiresAt, found := GlobalMacCache.GetWithExpiration(vars["mac"]); found {
		var node = &Node{Mac: vars["mac"], IP: index.(string), EndsAt: expiresAt}

		outgoingJSON, err := json.Marshal(node)

		if err != nil {
			unifiedapierrors.Error(res, err.Error(), http.StatusInternalServerError)
			return
		}

		fmt.Fprint(res, string(outgoingJSON))
		return
	}
	unifiedapierrors.Error(res, "Cannot find match for this MAC address", http.StatusNotFound)
	return
}

func (a *API) handleAllStats(res http.ResponseWriter, req *http.Request) {
	var result Items
	var interfaces pfconfigdriver.ListenInts
	pfconfigdriver.FetchDecodeSocket(ctx, &interfaces)

	if len(interfaces.Element) == 0 {
		result.Items = append(result.Items, Stats{})
	}
	for _, i := range interfaces.Element {
		if h, ok := intNametoInterface[i]; ok {
			stat := h.handleAPIReq(a.Ctx, APIReq{Req: "stats", NetInterface: i, NetWork: ""}, a.DB)
			for _, s := range stat.([]Stats) {
				result.Items = append(result.Items, s)
			}
		}
	}

	result.Status = "200"
	outgoingJSON, error := json.Marshal(result)

	if error != nil {
		unifiedapierrors.Error(res, error.Error(), http.StatusInternalServerError)
		return
	}

	fmt.Fprint(res, string(outgoingJSON))
	return
}

func (a *API) handleStats(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if h, ok := intNametoInterface[vars["int"]]; ok {
		stat := h.handleAPIReq(a.Ctx, APIReq{Req: "stats", NetInterface: vars["int"], NetWork: vars["network"]}, a.DB)

		outgoingJSON, err := json.Marshal(stat)

		if err != nil {
			unifiedapierrors.Error(res, err.Error(), http.StatusInternalServerError)
			return
		}

		fmt.Fprint(res, string(outgoingJSON))
		return
	}

	unifiedapierrors.Error(res, "Interface not found", http.StatusNotFound)
	return
}

func (a *API) handleDuplicates(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if h, ok := intNametoInterface[vars["int"]]; ok {
		stat := h.handleAPIReq(a.Ctx, APIReq{Req: "duplicates", NetInterface: vars["int"], NetWork: vars["network"]}, a.DB)

		outgoingJSON, err := json.Marshal(stat)

		if err != nil {
			unifiedapierrors.Error(res, err.Error(), http.StatusInternalServerError)
			return
		}

		fmt.Fprint(res, string(outgoingJSON))
		return
	}

	unifiedapierrors.Error(res, "Interface not found", http.StatusNotFound)
	return
}

func (a *API) handleDebug(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if h, ok := intNametoInterface[vars["int"]]; ok {
		stat := h.handleAPIReq(a.Ctx, APIReq{Req: "debug", NetInterface: vars["int"], Role: vars["role"]}, a.DB)

		outgoingJSON, err := json.Marshal(stat)

		if err != nil {
			unifiedapierrors.Error(res, err.Error(), http.StatusInternalServerError)
			return
		}

		fmt.Fprint(res, string(outgoingJSON))
		return
	}
	unifiedapierrors.Error(res, "Interface not found", http.StatusNotFound)
	return
}

func (a *API) handleReleaseIP(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	_ = InterfaceScopeFromMac(a.Ctx, vars["mac"])

	var result = &Info{Mac: vars["mac"], Status: "ACK"}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		log.LoggerWContext(a.Ctx).Error("Error releasing IP: " + err.Error() + " mac=" + vars["mac"])
	}
}

func (a *API) handleOverrideOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	body, err := io.ReadAll(io.LimitReader(req.Body, 1048576))
	if err != nil {
		log.LoggerWContext(a.Ctx).Error("Error reading request body: " + err.Error() + " mac=" + vars["mac"])
		unifiedapierrors.Error(res, err.Error(), http.StatusBadRequest)
		return
	}
	if err := req.Body.Close(); err != nil {
		log.LoggerWContext(a.Ctx).Error("Error closing request body: " + err.Error() + " mac=" + vars["mac"])
		unifiedapierrors.Error(res, err.Error(), http.StatusInternalServerError)
		return
	}

	// Insert information in MySQL
	if !MysqlInsert(a.Ctx, vars["mac"], sharedutils.ConvertToString(body), a.DB) {
		log.LoggerWContext(a.Ctx).Error("Failed to insert MAC options into database" + " mac=" + vars["mac"])
		unifiedapierrors.Error(res, "Failed to save options", http.StatusInternalServerError)
		return
	}

	var result = &Info{Mac: vars["mac"], Status: "ACK"}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		log.LoggerWContext(a.Ctx).Error("Error adding MAC options: " + err.Error() + " mac=" + vars["mac"])
	}
}

func (a *API) handleOverrideNetworkOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	body, err := io.ReadAll(io.LimitReader(req.Body, 1048576))
	if err != nil {
		log.LoggerWContext(a.Ctx).Error("Error reading request body: " + err.Error())
		unifiedapierrors.Error(res, err.Error(), http.StatusBadRequest)
		return
	}
	if err := req.Body.Close(); err != nil {
		log.LoggerWContext(a.Ctx).Error("Error closing request body: " + err.Error())
		unifiedapierrors.Error(res, err.Error(), http.StatusInternalServerError)
		return
	}

	// Insert information in MySQL
	if !MysqlInsert(a.Ctx, vars["network"], sharedutils.ConvertToString(body), a.DB) {
		log.LoggerWContext(a.Ctx).Error("Failed to insert network options into database")
		unifiedapierrors.Error(res, "Failed to save options", http.StatusInternalServerError)
		return
	}

	var result = &Info{Network: vars["network"], Status: "ACK"}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		log.LoggerWContext(ctx).Error("Error adding network options: " + err.Error())
	}
}

func (a *API) handleRemoveOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	var result = &Info{Mac: vars["mac"], Status: "ACK"}

	err := MysqlDel(vars["mac"], a.DB)
	if !err {
		result = &Info{Mac: vars["mac"], Status: "NAK"}
	}
	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		log.LoggerWContext(ctx).Error("Error removing MAC options: " + err.Error() + " mac=" + vars["mac"])
	}
}

func (a *API) handleRemoveNetworkOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	var result = &Info{Network: vars["network"], Status: "ACK"}

	err := MysqlDel(vars["network"], a.DB)
	if !err {
		result = &Info{Network: vars["network"], Status: "NAK"}
	}
	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		log.LoggerWContext(ctx).Error("Error removing network options: " + err.Error())
	}
}

func decodeOptions(ctx context.Context, b string, db *sql.DB) (map[dhcp.OptionCode][]byte, error) {
	var options []Options
	_, value := MysqlGet(ctx, b, db)
	decodedValue := sharedutils.ConvertToByte(value)
	var dhcpOptions = make(map[dhcp.OptionCode][]byte)
	if err := json.Unmarshal(decodedValue, &options); err != nil {
		return dhcpOptions, errors.New("Unable to decode the option")
	}
	for _, option := range options {
		var Value interface{}
		switch option.Type {
		case "ipaddr":
			Value = net.ParseIP(option.Value)
			dhcpOptions[option.Option] = Value.(net.IP).To4()
		case "string":
			Value = option.Value
			dhcpOptions[option.Option] = []byte(Value.(string))
		case "int":
			Value = option.Value
			val, _ := strconv.Atoi(Value.(string))
			bs := make([]byte, 4)
			binary.BigEndian.PutUint32(bs, uint32(val))
			dhcpOptions[option.Option] = bs
		}
	}

	return dhcpOptions, nil
}

func extractMembers(v Network) ([]Node, []string, int) {
	var Members []Node
	var Macs []string
	// hwcache.Items() returns a snapshot under the cache's own mutex; no
	// outer lock needed.
	members := v.dhcpHandler.hwcache.Items()
	var Count int
	Count = 0
	for i, item := range members {
		Count++
		result := make(net.IP, 4)
		binary.BigEndian.PutUint32(result, binary.BigEndian.Uint32(v.dhcpHandler.start.To4())+uint32(item.Object.(int)))
		_, mac, _ := v.dhcpHandler.available.GetMACIndex(uint64(item.Object.(int)))
		error := "0"
		if i != mac {
			error = "1"
		}
		Macs = append(Macs, i)
		Members = append(Members, Node{IP: result.String(), Mac: i, Pool: mac, Error: error, EndsAt: time.Unix(0, item.Expiration)})
	}
	return Members, Macs, Count
}

func (h *Interface) handleAPIReq(ctx context.Context, Request APIReq, db *sql.DB) interface{} {
	var stats []Stats

	if Request.Req == "duplicates" {
		for _, v := range h.network {
			Members, Macs, _ := extractMembers(v)

			inPoolNotInCache, DuplicateInPool := v.dhcpHandler.available.GetIssues(Macs)
			var DupInPool map[string]string
			DupInPool = make(map[string]string)
			for key, val := range DuplicateInPool {
				result2 := make(net.IP, 4)
				binary.BigEndian.PutUint32(result2, binary.BigEndian.Uint32(v.dhcpHandler.start.To4())+uint32(key))
				DupInPool[result2.String()] = val
			}

			stats = append(stats, Stats{EthernetName: Request.NetInterface, Net: v.network.String(), Category: v.dhcpHandler.role, Members: Members, Size: v.dhcpHandler.leaseRange, InPoolNotInCache: inPoolNotInCache, DuplicateInPool: DupInPool})
		}
		return stats
	}

	if Request.Req == "stats" {
		for _, v := range h.network {
			ipv4Addr, _, erro := net.ParseCIDR(Request.NetWork + "/32")
			if erro == nil {
				if !(v.network.Contains(ipv4Addr)) {
					continue
				}
			}
			var Options map[string]string
			Options = make(map[string]string)
			Options["optionIPAddressLeaseTime"] = v.dhcpHandler.leaseDuration.String()
			for option, value := range v.dhcpHandler.options {
				key := []byte(option.String())
				key[0] = key[0] | ('a' - 'A')
				Options[string(key)] = Tlv.Tlvlist[int(option)].Transform.String(value)
			}

			// Add network options on the fly
			x, err := decodeOptions(ctx, v.network.IP.String(), db)
			if err == nil {
				for key, value := range x {
					Options[key.String()] = Tlv.Tlvlist[int(key)].Transform.String(value)
				}
			}
			Members, _, Count := extractMembers(v)
			var Status string
			_, reserved := IPsFromRange(v.dhcpHandler.ipReserved)
			if reserved != 1 {
				Count = Count + reserved
			}

			availableCount := int(v.dhcpHandler.available.FreeIPsRemaining())
			usedCount := (v.dhcpHandler.leaseRange - availableCount)
			percentfree := int((float64(availableCount) / float64(v.dhcpHandler.leaseRange)) * 100)
			percentused := int((float64(usedCount) / float64(v.dhcpHandler.leaseRange)) * 100)

			if Count == (v.dhcpHandler.leaseRange - availableCount) {
				Status = "Normal"
			} else {
				Status = "Calculated available IP " + strconv.Itoa(v.dhcpHandler.leaseRange-Count) + " is different than what we have available in the pool " + strconv.Itoa(availableCount)
			}

			stats = append(stats, Stats{EthernetName: Request.NetInterface, Net: v.network.String(), Free: availableCount, Category: v.dhcpHandler.role, Options: Options, Members: Members, Status: Status, Size: v.dhcpHandler.leaseRange, Used: usedCount, PercentFree: percentfree, PercentUsed: percentused})
		}
		return stats
	}

	// Debug
	if Request.Req == "debug" {
		for _, v := range h.network {
			if Request.Role == v.dhcpHandler.role {
				spew.Dump(v.dhcpHandler.hwcache)
				stats = append(stats, Stats{EthernetName: Request.NetInterface, Net: v.network.String(), Free: int(v.dhcpHandler.available.FreeIPsRemaining()), Category: v.dhcpHandler.role, Status: "Debug finished"})
			}
		}
		return stats
	}

	return nil
}

// dhcpMessageContentType is the media type of a raw DHCP message body,
// mirroring application/dns-message (RFC 8484).
const dhcpMessageContentType = "application/dhcp-message"

// handleMessage serves DHCP over HTTP: POST /api/v1/dhcp/message with the raw
// DHCP request as body returns the raw DHCP reply as body (200), or 204 when
// pfdhcp has nothing to answer (unknown scope, duplicate transaction...).
//
// The request must be relayed (giaddr set): it is answered by the synthetic
// connector interface, whose scopes are the pfconnector-remote VLAN
// interfaces with DHCP enabled, and giaddr is what selects the scope. giaddr
// is also used as server identifier so that clients renew against the relay.
// pfconnector-server is the only caller and has already checked that giaddr
// belongs to the connector that sent the message.
func (a *API) handleMessage(res http.ResponseWriter, req *http.Request) {
	body, err := io.ReadAll(io.LimitReader(req.Body, 1501))
	if err != nil || len(body) < 240 || len(body) > 1500 {
		unifiedapierrors.Error(res, "Body must be a DHCP message (240..1500 bytes)", http.StatusBadRequest)
		return
	}
	p := dhcp.Packet(body)
	if p.OpCode() != dhcp.BootRequest || p.HLen() > 16 {
		unifiedapierrors.Error(res, "Not a BOOTREQUEST", http.StatusBadRequest)
		return
	}
	options := p.ParseOptions()
	t := options[dhcp.OptionDHCPMessageType]
	if len(t) != 1 {
		unifiedapierrors.Error(res, "Missing DHCP message type", http.StatusBadRequest)
		return
	}
	msgType := dhcp.MessageType(t[0])
	if msgType < dhcp.Discover || msgType > dhcp.Inform {
		unifiedapierrors.Error(res, "Unsupported DHCP message type", http.StatusBadRequest)
		return
	}
	giaddr := p.GIAddr()
	if giaddr.Equal(net.IPv4zero) {
		unifiedapierrors.Error(res, "giaddr must be set (relayed request)", http.StatusBadRequest)
		return
	}
	iface, ok := intNametoInterface[ConnectorInterfaceName]
	if !ok {
		unifiedapierrors.Error(res, "No connector DHCP scope configured", http.StatusNotFound)
		return
	}

	// The relay is the "client address" pfdhcp would otherwise have read from
	// the socket; giaddr is the server identifier advertised to the client.
	answer := iface.ServeDHCP(a.Ctx, p, msgType, &net.UDPAddr{IP: giaddr, Port: bootpServer}, giaddr.To4(), a.DB)
	if answer.D == nil {
		res.WriteHeader(http.StatusNoContent)
		return
	}
	res.Header().Set("Content-Type", dhcpMessageContentType)
	res.WriteHeader(http.StatusOK)
	res.Write(answer.D)
}
