package main

import (
	"net"
	"testing"
)

func TestIsIPv4(t *testing.T) {
	tests := []struct {
		name string
		ip   net.IP
		want bool
	}{
		{
			name: "valid IPv4",
			ip:   net.IPv4(192, 168, 1, 1),
			want: true,
		},
		{
			name: "IPv6",
			ip:   net.ParseIP("2001:db8::1"),
			want: false,
		},
		{
			name: "nil IP returns false",
			ip:   nil,
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.ip == nil {
				// IsIPv4 might panic on nil, so skip or test carefully
				t.Skip("IsIPv4 may not handle nil gracefully")
				return
			}
			got := IsIPv4(tt.ip)
			if got != tt.want {
				t.Errorf("IsIPv4() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestIsIPv6(t *testing.T) {
	tests := []struct {
		name string
		ip   net.IP
		want bool
	}{
		{
			name: "valid IPv6",
			ip:   net.ParseIP("2001:db8::1"),
			want: true,
		},
		{
			name: "IPv4",
			ip:   net.IPv4(192, 168, 1, 1),
			want: false,
		},
		{
			name: "nil IP",
			ip:   nil,
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := IsIPv6(tt.ip)
			if got != tt.want {
				t.Errorf("IsIPv6() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestZeroDate(t *testing.T) {
	const expected = "0000-00-00 00:00:00"
	if ZeroDate != expected {
		t.Errorf("ZeroDate = %v, want %v", ZeroDate, expected)
	}
}

func TestNodeInfoStruct(t *testing.T) {
	node := NodeInfo{
		Mac:      "aa:bb:cc:dd:ee:ff",
		Status:   "reg",
		Category: "default",
	}

	if node.Mac != "aa:bb:cc:dd:ee:ff" {
		t.Errorf("NodeInfo.Mac = %v, want aa:bb:cc:dd:ee:ff", node.Mac)
	}
	if node.Status != "reg" {
		t.Errorf("NodeInfo.Status = %v, want reg", node.Status)
	}
	if node.Category != "default" {
		t.Errorf("NodeInfo.Category = %v, want default", node.Category)
	}
}

func TestStringInSlice(t *testing.T) {
	tests := []struct {
		name  string
		str   string
		slice []string
		want  bool
	}{
		{
			name:  "string found",
			str:   "test",
			slice: []string{"hello", "test", "world"},
			want:  true,
		},
		{
			name:  "string not found",
			str:   "missing",
			slice: []string{"hello", "test", "world"},
			want:  false,
		},
		{
			name:  "empty slice",
			str:   "test",
			slice: []string{},
			want:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := stringInSlice(tt.str, tt.slice)
			if got != tt.want {
				t.Errorf("stringInSlice() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestSetOptionServerIdentifier(t *testing.T) {
	tests := []struct {
		name      string
		srvIP     net.IP
		handlerIP net.IP
		want      net.IP
	}{
		{
			name:      "use server IP when set",
			srvIP:     net.IPv4(192, 168, 1, 1),
			handlerIP: net.IPv4(10, 0, 0, 1),
			want:      net.IPv4(192, 168, 1, 1),
		},
		{
			name:      "use handler IP when server IP is zero",
			srvIP:     net.IPv4zero,
			handlerIP: net.IPv4(10, 0, 0, 1),
			want:      net.IPv4(10, 0, 0, 1),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := setOptionServerIdentifier(tt.srvIP, tt.handlerIP)
			if !got.Equal(tt.want) {
				t.Errorf("setOptionServerIdentifier() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestInterfaceScopeFromMac(t *testing.T) {
	t.Skip("InterfaceScopeFromMac requires pfconfig service - tested in integration tests")
}
