package main

import (
	"context"
	"net"
	"strings"
	"testing"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func TestShuffleDNS(t *testing.T) {
	// Mock configuration for testing
	confNet := pfconfigdriver.RessourseNetworkConf{
		Type:       "inlinel2",
		NatDNS:     "disabled",
		Dns:        "8.8.8.8,8.8.4.4",
		ClusterIPs: "192.168.1.1,192.168.1.2",
		Dnsvip:     "192.168.1.100",
		Interface:  pfconfigdriver.Interface{InterfaceName: "eth0"},
	}

	// Test case 1: Inline L2 type with NAT DNS disabled
	result := ShuffleDNS(context.Background(), confNet)
	if len(result) == 0 {
		t.Errorf("Expected non-empty DNS list, got empty")
	}

	// Test case 2: Cluster IPs with DNS VIP
	confNet.Type = "cluster"
	confNet.Dnsvip = "192.168.1.100"
	result = ShuffleDNS(context.Background(), confNet)
	expected := net.ParseIP("192.168.1.100").To4()
	if string(result) != string(expected) {
		t.Errorf("Expected DNS VIP %v, got %v", expected, result)
	}

	// Test case 3: Cluster IPs without DNS VIP
	confNet.Dnsvip = ""
	result = ShuffleDNS(context.Background(), confNet)
	if len(result) == 0 {
		t.Errorf("Expected non-empty DNS list, got empty")
	}
}

func TestShuffleGateway(t *testing.T) {
	// Test case 1: Gateway is explicitly set
	confNet := pfconfigdriver.RessourseNetworkConf{
		Gateway: "192.168.1.1",
		NextHop: "",
	}
	result := ShuffleGateway(context.Background(), confNet)
	expected := net.ParseIP("192.168.1.1").To4()
	if string(result) != string(expected) {
		t.Errorf("Expected gateway %v, got %v", expected, result)
	}

	// Test case 2: Cluster IPs with ForceGatewayVIP
	confNet = pfconfigdriver.RessourseNetworkConf{
		ClusterIPs:      "192.168.1.2,192.168.1.3",
		ForceGatewayVIP: "192.168.1.100",
	}
	result = ShuffleGateway(context.Background(), confNet)
	expected = net.ParseIP("192.168.1.100").To4()
	if string(result) != string(expected) {
		t.Errorf("Expected ForceGatewayVIP %v, got %v", expected, result)
	}

	// Test case 3: Cluster IPs without ForceGatewayVIP
	confNet = pfconfigdriver.RessourseNetworkConf{
		ClusterIPs: "192.168.1.2,192.168.1.3",
	}
	result = ShuffleGateway(context.Background(), confNet)
	if len(result) == 0 {
		t.Errorf("Expected non-empty gateway list, got empty")
	}

	// Test case 4: Inline L2 type with NAT disabled
	confNet = pfconfigdriver.RessourseNetworkConf{
		Type:       "inlinel2",
		NatEnabled: "disabled",
		Gateway:    "192.168.1.1",
	}
	result = ShuffleGateway(context.Background(), confNet)
	expected = net.ParseIP("192.168.1.1").To4()
	if string(result) != string(expected) {
		t.Errorf("Expected gateway %v, got %v", expected, result)
	}
}

func TestReorganizeIPsByModulo(t *testing.T) {
	// Test case 1: Empty IP list
	emptyIPs := []net.IP{}
	result := ReorganizeIPsByModulo(emptyIPs, 10)
	if len(result) != 0 {
		t.Errorf("Expected empty result, got %v", result)
	}

	// Test case 2: Single IP in the list
	singleIP := []net.IP{net.ParseIP("192.168.1.1")}
	result = ReorganizeIPsByModulo(singleIP, 10)
	if len(result) != 1 || !result[0].Equal(singleIP[0]) {
		t.Errorf("Expected %v, got %v", singleIP, result)
	}

	// Test case 3: Multiple IPs with a valid modulo
	multipleIPs := []net.IP{
		net.ParseIP("192.168.1.1"),
		net.ParseIP("192.168.1.2"),
		net.ParseIP("192.168.1.3"),
		net.ParseIP("192.168.1.4"),
	}
	result = ReorganizeIPsByModulo(multipleIPs, 3)
	if len(result) != len(multipleIPs) {
		t.Errorf("Expected result length %d, got %d", len(multipleIPs), len(result))
	}

	// Ensure all original IPs are present in the result
	for _, ip := range multipleIPs {
		found := false
		for _, resIP := range result {
			if ip.Equal(resIP) {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("Expected IP %v not found in result %v", ip, result)
		}
	}

	// Test case 4: Modulo value of 0
	result = ReorganizeIPsByModulo(multipleIPs, 0)
	if len(result) != len(multipleIPs) {
		t.Errorf("Expected result length %d, got %d", len(multipleIPs), len(result))
	}
	for i, ip := range multipleIPs {
		if !ip.Equal(result[i]) {
			t.Errorf("Expected IP %v at index %d, got %v", ip, i, result[i])
		}
	}

	// Test case 5: Modulo value greater than IP list length
	result = ReorganizeIPsByModulo(multipleIPs, 10)
	if len(result) != len(multipleIPs) {
		t.Errorf("Expected result length %d, got %d", len(multipleIPs), len(result))
	}
	for _, ip := range multipleIPs {
		found := false
		for _, resIP := range result {
			if ip.Equal(resIP) {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("Expected IP %v not found in result %v", ip, result)
		}
	}
}

func TestShuffleNetIP(t *testing.T) {
	// Test case 1: Single IP in the array
	singleIP := []net.IP{net.ParseIP("192.168.1.1")}
	result := ShuffleNetIP(singleIP, 0)
	expected := singleIP[0].To4()
	if string(result) != string(expected) {
		t.Errorf("Expected %v, got %v", expected, result)
	}

	// Test case 2: Multiple IPs in the array
	multipleIPs := []net.IP{
		net.ParseIP("192.168.1.1"),
		net.ParseIP("192.168.1.2"),
		net.ParseIP("192.168.1.3"),
	}

	result = ShuffleNetIP(multipleIPs, 12345) // Using a fixed random seed

	if len(result) != len(multipleIPs)*4 {
		t.Errorf("Expected result length %d, got %d", len(multipleIPs)*4, len(result))
	}

	// Test case 3: Empty array
	emptyIPs := []net.IP{}
	result = ShuffleNetIP(emptyIPs, 0)
	if len(result) != 0 {
		t.Errorf("Expected empty result, got %v", result)
	}

	// Test case 4: Randomized shuffle
	randomIPs := []net.IP{
		net.ParseIP("10.0.0.1"),
		net.ParseIP("10.0.0.2"),
		net.ParseIP("10.0.0.3"),
	}
	result1 := ShuffleNetIP(randomIPs, 12345)
	result2 := ShuffleNetIP(randomIPs, 67890)
	if string(result1) == string(result2) {
		t.Errorf("Expected different results for different seeds, got identical results")
	}
}

func TestShuffle(t *testing.T) {
	// Test case 1: Single address
	addresses := "192.168.1.1"
	excluded := []string{}
	result := Shuffle(addresses, excluded)
	expected := net.ParseIP("192.168.1.1").To4()
	if string(result) != string(expected) {
		t.Errorf("Expected %v, got %v", expected, result)
	}

	// Test case 2: Multiple addresses with no exclusions
	addresses = "192.168.1.1,192.168.1.2,192.168.1.3"
	excluded = []string{}
	result = Shuffle(addresses, excluded)
	if len(result) != 12 { // 3 IPs * 4 bytes each
		t.Errorf("Expected result length 12, got %d", len(result))
	}

	// Test case 3: Multiple addresses with exclusions
	addresses = "192.168.1.1,192.168.1.2,192.168.1.3"
	excluded = []string{"192.168.1.2"}
	result = Shuffle(addresses, excluded)
	if strings.Contains(string(result), "192.168.1.2") {
		t.Errorf("Excluded address 192.168.1.2 should not be in the result")
	}

	// Test case 4: Empty addresses
	addresses = ""
	excluded = []string{}
	result = Shuffle(addresses, excluded)
	if len(result) != 0 {
		t.Errorf("Expected empty result, got %v", result)
	}

	// Test case 5: All addresses excluded
	addresses = "192.168.1.1,192.168.1.2"
	excluded = []string{"192.168.1.1", "192.168.1.2"}
	result = Shuffle(addresses, excluded)
	if len(result) != 0 {
		t.Errorf("Expected empty result, got %v", result)
	}
}

func TestShuffleIP(t *testing.T) {
	// Test case 1: Single IP
	singleIP := []byte{192, 168, 1, 1}
	result := ShuffleIP(singleIP, 0)
	expected := singleIP
	if string(result) != string(expected) {
		t.Errorf("Expected %v, got %v", expected, result)
	}

	// Test case 2: Multiple IPs
	multipleIPs := []byte{
		192, 168, 1, 1,
		192, 168, 1, 2,
		192, 168, 1, 3,
	}
	result = ShuffleIP(multipleIPs, 12345) // Using a fixed random seed
	if len(result) != len(multipleIPs) {
		t.Errorf("Expected result length %d, got %d", len(multipleIPs), len(result))
	}

	// Test case 3: Empty input
	emptyIPs := []byte{}
	result = ShuffleIP(emptyIPs, 0)
	if len(result) != 0 {
		t.Errorf("Expected empty result, got %v", result)
	}

	// Test case 4: Randomized shuffle
	randomIPs := []byte{
		10, 0, 0, 1,
		10, 0, 0, 2,
		10, 0, 0, 3,
	}
	result1 := ShuffleIP(randomIPs, 12345)
	result2 := ShuffleIP(randomIPs, 67890)
	if string(result1) == string(result2) {
		t.Errorf("Expected different results for different seeds, got identical results")
	}
}
