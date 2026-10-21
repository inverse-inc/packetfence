package main

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	cache "github.com/fdurand/go-cache"
	"github.com/gorilla/mux"
)

func TestHandleIP2Mac(t *testing.T) {
	// Initialize the global cache
	GlobalIPCache = cache.New(5*time.Minute, 10*time.Minute)

	tests := []struct {
		name           string
		ip             string
		setupCache     func()
		expectedStatus int
		expectedMac    string
	}{
		{
			name: "found in cache",
			ip:   "192.168.1.100",
			setupCache: func() {
				GlobalIPCache.Set("192.168.1.100", "aa:bb:cc:dd:ee:ff", 5*time.Minute)
			},
			expectedStatus: http.StatusOK,
			expectedMac:    "aa:bb:cc:dd:ee:ff",
		},
		{
			name:           "not found in cache",
			ip:             "192.168.1.101",
			setupCache:     func() {},
			expectedStatus: http.StatusNotFound,
			expectedMac:    "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setupCache()

			api := &API{
				Ctx: context.Background(),
			}

			req := httptest.NewRequest(http.MethodGet, "/api/v1/dhcp/ip2mac/"+tt.ip, nil)
			req = mux.SetURLVars(req, map[string]string{"ip": tt.ip})
			w := httptest.NewRecorder()

			api.handleIP2Mac(w, req)

			if w.Code != tt.expectedStatus {
				t.Errorf("handleIP2Mac() status = %v, want %v", w.Code, tt.expectedStatus)
			}

			if tt.expectedStatus == http.StatusOK {
				var node Node
				err := json.NewDecoder(w.Body).Decode(&node)
				if err != nil {
					t.Fatalf("Failed to decode response: %v", err)
				}
				if node.Mac != tt.expectedMac {
					t.Errorf("handleIP2Mac() mac = %v, want %v", node.Mac, tt.expectedMac)
				}
				if node.IP != tt.ip {
					t.Errorf("handleIP2Mac() ip = %v, want %v", node.IP, tt.ip)
				}
			}
		})
	}
}

func TestNodeStruct(t *testing.T) {
	now := time.Now()
	node := Node{
		Mac:    "aa:bb:cc:dd:ee:ff",
		IP:     "192.168.1.100",
		Pool:   "default",
		Error:  "",
		EndsAt: now,
	}

	data, err := json.Marshal(node)
	if err != nil {
		t.Fatalf("Failed to marshal Node: %v", err)
	}

	var decoded Node
	err = json.Unmarshal(data, &decoded)
	if err != nil {
		t.Fatalf("Failed to unmarshal Node: %v", err)
	}

	if decoded.Mac != node.Mac {
		t.Errorf("Decoded Mac = %v, want %v", decoded.Mac, node.Mac)
	}
	if decoded.IP != node.IP {
		t.Errorf("Decoded IP = %v, want %v", decoded.IP, node.IP)
	}
	if decoded.Pool != node.Pool {
		t.Errorf("Decoded Pool = %v, want %v", decoded.Pool, node.Pool)
	}
}

func TestStatsStruct(t *testing.T) {
	stats := Stats{
		EthernetName:     "eth0",
		Net:              "192.168.1.0/24",
		Free:             50,
		PercentFree:      50,
		Used:             50,
		PercentUsed:      50,
		Category:         "default",
		Options:          map[string]string{"router": "192.168.1.1"},
		Members:          []Node{},
		Status:           "enabled",
		Size:             100,
		InPoolNotInCache: []string{},
		DuplicateInPool:  map[string]string{},
	}

	data, err := json.Marshal(stats)
	if err != nil {
		t.Fatalf("Failed to marshal Stats: %v", err)
	}

	var decoded Stats
	err = json.Unmarshal(data, &decoded)
	if err != nil {
		t.Fatalf("Failed to unmarshal Stats: %v", err)
	}

	if decoded.EthernetName != stats.EthernetName {
		t.Errorf("Decoded EthernetName = %v, want %v", decoded.EthernetName, stats.EthernetName)
	}
	if decoded.Free != stats.Free {
		t.Errorf("Decoded Free = %v, want %v", decoded.Free, stats.Free)
	}
	if decoded.Used != stats.Used {
		t.Errorf("Decoded Used = %v, want %v", decoded.Used, stats.Used)
	}
}

func TestAPIReqStruct(t *testing.T) {
	req := APIReq{
		Req:          "get_lease",
		NetInterface: "eth0",
		NetWork:      "192.168.1.0/24",
		Mac:          "aa:bb:cc:dd:ee:ff",
		Role:         "default",
	}

	if req.Req != "get_lease" {
		t.Errorf("APIReq.Req = %v, want get_lease", req.Req)
	}
	if req.NetInterface != "eth0" {
		t.Errorf("APIReq.NetInterface = %v, want eth0", req.NetInterface)
	}
	if req.Mac != "aa:bb:cc:dd:ee:ff" {
		t.Errorf("APIReq.Mac = %v, want aa:bb:cc:dd:ee:ff", req.Mac)
	}
}

func TestInfoStruct(t *testing.T) {
	info := Info{
		Status:  "success",
		Mac:     "aa:bb:cc:dd:ee:ff",
		Network: "192.168.1.0/24",
	}

	data, err := json.Marshal(info)
	if err != nil {
		t.Fatalf("Failed to marshal Info: %v", err)
	}

	var decoded Info
	err = json.Unmarshal(data, &decoded)
	if err != nil {
		t.Fatalf("Failed to unmarshal Info: %v", err)
	}

	if decoded.Status != info.Status {
		t.Errorf("Decoded Status = %v, want %v", decoded.Status, info.Status)
	}
	if decoded.Mac != info.Mac {
		t.Errorf("Decoded Mac = %v, want %v", decoded.Mac, info.Mac)
	}
}

func TestOptionsStruct(t *testing.T) {
	opt := Options{
		Option: 3, // Router option
		Value:  "192.168.1.1",
		Type:   "ip",
	}

	data, err := json.Marshal(opt)
	if err != nil {
		t.Fatalf("Failed to marshal Options: %v", err)
	}

	var decoded Options
	err = json.Unmarshal(data, &decoded)
	if err != nil {
		t.Fatalf("Failed to unmarshal Options: %v", err)
	}

	if decoded.Option != opt.Option {
		t.Errorf("Decoded Option = %v, want %v", decoded.Option, opt.Option)
	}
	if decoded.Value != opt.Value {
		t.Errorf("Decoded Value = %v, want %v", decoded.Value, opt.Value)
	}
	if decoded.Type != opt.Type {
		t.Errorf("Decoded Type = %v, want %v", decoded.Type, opt.Type)
	}
}

func TestItemsStruct(t *testing.T) {
	items := Items{
		Items: []Stats{
			{
				EthernetName: "eth0",
				Net:          "192.168.1.0/24",
				Free:         50,
				Used:         50,
				Status:       "enabled",
			},
		},
		Status: "success",
	}

	data, err := json.Marshal(items)
	if err != nil {
		t.Fatalf("Failed to marshal Items: %v", err)
	}

	var decoded Items
	err = json.Unmarshal(data, &decoded)
	if err != nil {
		t.Fatalf("Failed to unmarshal Items: %v", err)
	}

	if decoded.Status != items.Status {
		t.Errorf("Decoded Status = %v, want %v", decoded.Status, items.Status)
	}
	if len(decoded.Items) != len(items.Items) {
		t.Errorf("Decoded Items length = %v, want %v", len(decoded.Items), len(items.Items))
	}
}

func TestIPv4ToInt(t *testing.T) {
	tests := []struct {
		name string
		ip   net.IP
		want uint32
	}{
		{
			name: "192.168.1.1",
			ip:   net.IPv4(192, 168, 1, 1),
			want: 3232235777, // 192*256^3 + 168*256^2 + 1*256 + 1
		},
		{
			name: "10.0.0.1",
			ip:   net.IPv4(10, 0, 0, 1),
			want: 167772161,
		},
		{
			name: "0.0.0.0",
			ip:   net.IPv4(0, 0, 0, 0),
			want: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Convert IP to uint32 using binary encoding
			ip4 := tt.ip.To4()
			if ip4 == nil {
				t.Skip("Not an IPv4 address")
			}
			got := binary.BigEndian.Uint32(ip4)
			if got != tt.want {
				t.Errorf("IPv4 to int conversion(%v) = %v, want %v", tt.ip, got, tt.want)
			}
		})
	}
}
