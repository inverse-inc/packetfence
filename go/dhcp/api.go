package main

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/api-frontend/unifiedapierrors"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	dhcp "github.com/krolaw/dhcp4"
)

// Node struct
type Node struct {
	Mac    string    `json:"mac"`
	IP     string    `json:"ip"`
	EndsAt time.Time `json:"ends_at"`
}

// Stats struct
type Stats struct {
	EthernetName string            `json:"interface"`
	Net          string            `json:"network"`
	Free         int               `json:"free"`
	PercentFree  int               `json:"percentfree"`
	Used         int               `json:"used"`
	PercentUsed  int               `json:"percentused"`
	Category     string            `json:"category"`
	Options      map[string]string `json:"options"`
	Members      []Node            `json:"members"`
	Status       string            `json:"status"`
	Size         int               `json:"size"`
}

type Items struct {
	Items  []Stats `json:"items"`
	Status string  `json:"status"`
}

type ApiReq struct {
	Req          string
	NetInterface string
	NetWork      string
	Mac          string
	Role         string
}

type Options struct {
	Option dhcp.OptionCode `json:"option"`
	Value  string          `json:"value"`
	Type   string          `json:"type"`
}

type Info struct {
	Status  string `json:"status"`
	Mac     string `json:"mac,omitempty"`
	Network string `json:"network,omitempty"`
}

func handleIP2Mac(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if index, expiresAt, found := GlobalIpCache.GetWithExpiration(vars["ip"]); found {
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

func handleMac2Ip(res http.ResponseWriter, req *http.Request) {
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

func handleAllStats(res http.ResponseWriter, req *http.Request) {
	var result Items
	var interfaces pfconfigdriver.ListenInts
	pfconfigdriver.FetchDecodeSocket(ctx, &interfaces)

	if len(interfaces.Element) == 0 {
		result.Items = append(result.Items, Stats{})
	}
	for _, i := range interfaces.Element {
		if h, ok := intNametoInterface[i]; ok {
			stat := h.handleApiReq(ApiReq{Req: "stats", NetInterface: i, NetWork: ""})
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

func handleStats(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if h, ok := intNametoInterface[vars["int"]]; ok {
		stat := h.handleApiReq(ApiReq{Req: "stats", NetInterface: vars["int"], NetWork: vars["network"]})

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

func handleInitiaLease(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if h, ok := intNametoInterface[vars["int"]]; ok {
		stat := h.handleApiReq(ApiReq{Req: "initialease", NetInterface: vars["int"], NetWork: ""})

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

func handleDebug(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if h, ok := intNametoInterface[vars["int"]]; ok {
		stat := h.handleApiReq(ApiReq{Req: "debug", NetInterface: vars["int"], Role: vars["role"]})

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

func handleReleaseIP(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	_ = InterfaceScopeFromMac(vars["mac"])

	var result = &Info{Mac: vars["mac"], Status: "ACK"}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func handleOverrideOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	body, err := ioutil.ReadAll(io.LimitReader(req.Body, 1048576))
	if err != nil {
		panic(err)
	}
	if err := req.Body.Close(); err != nil {
		panic(err)
	}

	// Insert information in MySQL
	_ = MysqlInsert(vars["mac"], sharedutils.ConvertToString(body))

	var result = &Info{Mac: vars["mac"], Status: "ACK"}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func handleOverrideNetworkOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	body, err := ioutil.ReadAll(io.LimitReader(req.Body, 1048576))
	if err != nil {
		panic(err)
	}
	if err := req.Body.Close(); err != nil {
		panic(err)
	}

	// Insert information in MySQL
	_ = MysqlInsert(vars["network"], sharedutils.ConvertToString(body))

	var result = &Info{Network: vars["network"], Status: "ACK"}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func handleRemoveOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	var result = &Info{Mac: vars["mac"], Status: "ACK"}

	err := MysqlDel(vars["mac"])
	if !err {
		result = &Info{Mac: vars["mac"], Status: "NAK"}
	}
	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func handleRemoveNetworkOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	var result = &Info{Network: vars["network"], Status: "ACK"}

	err := MysqlDel(vars["network"])
	if !err {
		result = &Info{Network: vars["network"], Status: "NAK"}
	}
	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func decodeOptions(b string) (map[dhcp.OptionCode][]byte, bool) {
	var options []Options
	_, value := MysqlGet(b)
	decodedValue := sharedutils.ConvertToByte(value)
	var dhcpOptions = make(map[dhcp.OptionCode][]byte)
	if err := json.Unmarshal(decodedValue, &options); err != nil {
		return dhcpOptions, false
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
			dhcpOptions[option.Option] = []byte(Value.(string))
		}
	}
	return dhcpOptions, true
}

func (h *Interface) handleApiReq(Request ApiReq) interface{} {
	var stats []Stats

	// Send back stats
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
				Options[string(key)] = Tlv.Tlvlist[int(option)].Decode.String(value)
			}

			// Add network options on the fly
			x, err := decodeOptions(v.network.IP.String())
			if err {
				for key, value := range x {
					Options[key.String()] = Tlv.Tlvlist[int(key)].Decode.String(value)
				}
			}

			var Members []Node
			id, _ := GlobalTransactionLock.Lock()
			members := v.dhcpHandler.hwcache.Items()
			GlobalTransactionLock.Unlock(id)
			var Status string
			var Count int
			Count = 0
			for i, item := range members {
				Count++
				result := make(net.IP, 4)
				binary.BigEndian.PutUint32(result, binary.BigEndian.Uint32(v.dhcpHandler.start.To4())+uint32(item.Object.(int)))
				Members = append(Members, Node{IP: result.String(), Mac: i, EndsAt: time.Unix(0, item.Expiration)})
			}
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
	// Update the lease
	if Request.Req == "initialease" {

		for _, v := range h.network {
			// initiaLease(&v.dhcpHandler)
			stats = append(stats, Stats{EthernetName: Request.NetInterface, Net: v.network.String(), Category: v.dhcpHandler.role, Status: "Init Lease success"})
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
