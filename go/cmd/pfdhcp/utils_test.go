package main

import (
	"context"
	"net"
	"reflect"
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

func TestShuffleNetIP(t *testing.T) {
	// Test case 1: Single IP in the array
	singleIP := []net.IP{net.ParseIP("192.168.1.1")}
	result := ShuffleNetIP(context.Background(), singleIP)
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

	result = ShuffleNetIP(context.Background(), multipleIPs) // Using a fixed random seed
	if len(result) != len(multipleIPs)*4 {
		t.Errorf("Expected result length %d, got %d", len(multipleIPs)*4, len(result))
	}

	// Test case 3: Empty array
	emptyIPs := []net.IP{}
	result = ShuffleNetIP(context.Background(), emptyIPs)
	if len(result) != 0 {
		t.Errorf("Expected empty result, got %v", result)
	}

	// Test case 4: Randomized shuffle
	randomIPs := []net.IP{
		net.ParseIP("10.0.0.1"),
		net.ParseIP("10.0.0.2"),
		net.ParseIP("10.0.0.3"),
		net.ParseIP("10.0.0.4"),
		net.ParseIP("10.0.0.5"),
		net.ParseIP("10.0.0.6"),
		net.ParseIP("10.0.0.7"),
		net.ParseIP("10.0.0.8"),
		net.ParseIP("10.0.0.9"),
		net.ParseIP("10.0.0.10"),
		net.ParseIP("10.0.0.11"),
		net.ParseIP("10.0.0.12"),
	}
	result1 := ShuffleNetIP(context.Background(), randomIPs)
	result2 := ShuffleNetIP(context.Background(), randomIPs)
	if string(result1) == string(result2) {
		t.Errorf("Expected different results for different seeds, got identical results")
	}
}

func TestShuffle(t *testing.T) {
	// Test case 1: Single address
	addresses := "192.168.1.1"
	excluded := []string{}
	result := Shuffle(context.Background(), addresses, excluded)
	expected := net.ParseIP("192.168.1.1").To4()
	if string(result) != string(expected) {
		t.Errorf("Expected %v, got %v", expected, result)
	}

	// Test case 2: Multiple addresses with no exclusions
	addresses = "192.168.1.1,192.168.1.2,192.168.1.3"
	excluded = []string{}
	result = Shuffle(context.Background(), addresses, excluded)
	if len(result) != 12 { // 3 IPs * 4 bytes each
		t.Errorf("Expected result length 12, got %d", len(result))
	}

	// Test case 3: Multiple addresses with exclusions
	addresses = "192.168.1.1,192.168.1.2,192.168.1.3"
	excluded = []string{"192.168.1.2"}
	result = Shuffle(context.Background(), addresses, excluded)
	if strings.Contains(string(result), "192.168.1.2") {
		t.Errorf("Excluded address 192.168.1.2 should not be in the result")
	}

	// Test case 4: Empty addresses
	addresses = ""
	excluded = []string{}
	result = Shuffle(context.Background(), addresses, excluded)
	if len(result) != 0 {
		t.Errorf("Expected empty result, got %v", result)
	}

	// Test case 5: All addresses excluded
	addresses = "192.168.1.1,192.168.1.2"
	excluded = []string{"192.168.1.1", "192.168.1.2"}
	result = Shuffle(context.Background(), addresses, excluded)
	if len(result) != 0 {
		t.Errorf("Expected empty result, got %v", result)
	}
}

func TestShuffleIP(t *testing.T) {
	// Test case 1: Single IP
	singleIP := []byte{192, 168, 1, 1}
	result := ShuffleIP(context.Background(), singleIP)
	expected := singleIP
	if string(result) != string(expected) {
		t.Errorf("Expected %v, got %v", expected, result)
	}

	// Test case 2: Multiple IPs
	multipleIPs := []byte{
		192, 168, 1, 1,
		192, 168, 1, 2,
		192, 168, 1, 3,
		192, 168, 1, 4,
		192, 168, 1, 5,
		192, 168, 1, 6,
		192, 168, 1, 7,
		192, 168, 1, 8,
		192, 168, 1, 9,
		192, 168, 1, 10,
		192, 168, 1, 11,
		192, 168, 1, 12,
	}
	result = ShuffleIP(context.Background(), multipleIPs) // Using a fixed random seed
	if len(result) != len(multipleIPs) {
		t.Errorf("Expected result length %d, got %d", len(multipleIPs), len(result))
	}

	// Test case 3: Empty input
	emptyIPs := []byte{}
	result = ShuffleIP(context.Background(), emptyIPs)
	if len(result) != 0 {
		t.Errorf("Expected empty result, got %v", result)
	}

	// Test case 4: Randomized shuffle
	randomIPs := []byte{
		10, 0, 0, 1,
		10, 0, 0, 2,
		10, 0, 0, 3,
		10, 0, 0, 4,
		10, 0, 0, 5,
		10, 0, 0, 6,
		10, 0, 0, 7,
		10, 0, 0, 8,
		10, 0, 0, 9,
		10, 0, 0, 10,
		10, 0, 0, 11,
		10, 0, 0, 12,
	}
	result1 := ShuffleIP(context.Background(), randomIPs)
	result2 := ShuffleIP(context.Background(), randomIPs)
	if string(result1) == string(result2) {
		t.Errorf("Expected different results for different seeds, got identical results")
	}
}

func TestCryptoShuffle(t *testing.T) {
	// Prepare test data
	ips := []net.IP{
		net.IPv4(192, 168, 1, 1),
		net.IPv4(192, 168, 1, 2),
		net.IPv4(192, 168, 1, 3),
		net.IPv4(192, 168, 1, 4),
		net.IPv4(192, 168, 1, 5),
	}

	// Make a copy of the original slice for comparison
	original := make([]net.IP, len(ips))
	copy(original, ips)

	// Shuffle the IPs
	shuffled, err := cryptoShuffle(ips)
	if err != nil {
		t.Fatalf("Error during shuffle: %v", err)
	}

	// Ensure the shuffled slice contains the same elements as the original
	if len(shuffled) != len(original) {
		t.Fatalf("Expected shuffled length %d, got %d", len(original), len(shuffled))
	}

	// Check that all elements in the original slice are in the shuffled slice
	for _, ip := range original {
		found := false
		for _, shuffledIP := range shuffled {
			if reflect.DeepEqual(ip, shuffledIP) {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("IP %v from the original slice is missing in the shuffled slice", ip)
		}
	}

	// Check that the order has changed (most of the time)
	sameOrder := true
	for i := range original {
		if !original[i].Equal(shuffled[i]) {
			sameOrder = false
			break
		}
	}
	if sameOrder {
		t.Errorf("The order of the IPs did not change after shuffling")
	}
}
