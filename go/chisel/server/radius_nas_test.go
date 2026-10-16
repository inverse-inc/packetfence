package chserver

import (
	"net"
	"reflect"
	"testing"
)

func mustCIDR(t *testing.T, s string) *net.IPNet {
	t.Helper()
	_, n, err := net.ParseCIDR(s)
	if err != nil {
		t.Fatal(err)
	}
	return n
}

func TestRadiusNasKeys(t *testing.T) {
	keys := []string{
		"default", "100.64.0.1", "127.127.127.127",
		"192.168.1.22",
		"192.168.1.0/26",
		"192.168.1.7/26",
		"192.168.1.30/32",
		"10.10.0.0/16",
		"172.16.0.0/12",
		"172.20.1.1",
		"00:11:22:33:44:55",
	}

	tests := []struct {
		name     string
		networks []*net.IPNet
		want     []radiusNasKey
	}{
		{
			name:     "connector networks",
			networks: []*net.IPNet{mustCIDR(t, "192.168.1.0/24"), mustCIDR(t, "172.20.0.0/16")},
			want: []radiusNasKey{
				{Key: "172.16.0.0/12", Nasname: "172.16.0.0/12"},
				{Key: "172.20.1.1", Nasname: "172.20.1.1"},
				{Key: "192.168.1.0/26", Nasname: "192.168.1.0/26"},
				{Key: "192.168.1.22", Nasname: "192.168.1.22"},
				{Key: "192.168.1.30/32", Nasname: "192.168.1.30"},
				{Key: "192.168.1.7/26", Nasname: "192.168.1.0/26"},
			},
		},
		{
			name: "no connector networks",
			want: []radiusNasKey{
				{Key: "00:11:22:33:44:55", Nasname: "00:11:22:33:44:55"},
				{Key: "10.10.0.0/16", Nasname: "10.10.0.0/16"},
				{Key: "172.16.0.0/12", Nasname: "172.16.0.0/12"},
				{Key: "172.20.1.1", Nasname: "172.20.1.1"},
				{Key: "192.168.1.0/26", Nasname: "192.168.1.0/26"},
				{Key: "192.168.1.22", Nasname: "192.168.1.22"},
				{Key: "192.168.1.30/32", Nasname: "192.168.1.30"},
				{Key: "192.168.1.7/26", Nasname: "192.168.1.0/26"},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := radiusNasKeys(keys, tt.networks)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("radiusNasKeys() =\n%v\nwant\n%v", got, tt.want)
			}
		})
	}
}

func TestUniqueRadiusNasKeys(t *testing.T) {
	tests := []struct {
		name     string
		keys     []radiusNasKey
		want     []radiusNasKey
		wantDups []radiusNasDuplicate
	}{
		{
			name: "no duplicates",
			keys: []radiusNasKey{
				{Key: "192.168.1.0/26", Nasname: "192.168.1.0/26"},
				{Key: "192.168.1.22", Nasname: "192.168.1.22"},
			},
			want: []radiusNasKey{
				{Key: "192.168.1.0/26", Nasname: "192.168.1.0/26"},
				{Key: "192.168.1.22", Nasname: "192.168.1.22"},
			},
		},
		{
			name: "normalized key wins even when it comes later",
			keys: []radiusNasKey{
				{Key: "10.0.0.12/24", Nasname: "10.0.0.0/24"},
				{Key: "10.0.0.5", Nasname: "10.0.0.5"},
				{Key: "10.0.0.0/24", Nasname: "10.0.0.0/24"},
				{Key: "10.0.0.7/24", Nasname: "10.0.0.0/24"},
			},
			want: []radiusNasKey{
				{Key: "10.0.0.0/24", Nasname: "10.0.0.0/24"},
				{Key: "10.0.0.5", Nasname: "10.0.0.5"},
			},
			wantDups: []radiusNasDuplicate{
				{Key: "10.0.0.12/24", KeptKey: "10.0.0.0/24"},
				{Key: "10.0.0.7/24", KeptKey: "10.0.0.0/24"},
			},
		},
		{
			name: "no normalized key: the first one is kept",
			keys: []radiusNasKey{
				{Key: "10.0.0.12/24", Nasname: "10.0.0.0/24"},
				{Key: "10.0.0.7/24", Nasname: "10.0.0.0/24"},
			},
			want: []radiusNasKey{
				{Key: "10.0.0.12/24", Nasname: "10.0.0.0/24"},
			},
			wantDups: []radiusNasDuplicate{
				{Key: "10.0.0.7/24", KeptKey: "10.0.0.12/24"},
			},
		},
		{
			name: "single IP and its /32",
			keys: []radiusNasKey{
				{Key: "10.0.0.5", Nasname: "10.0.0.5"},
				{Key: "10.0.0.5/32", Nasname: "10.0.0.5"},
			},
			want: []radiusNasKey{
				{Key: "10.0.0.5", Nasname: "10.0.0.5"},
			},
			wantDups: []radiusNasDuplicate{
				{Key: "10.0.0.5/32", KeptKey: "10.0.0.5"},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, dups := uniqueRadiusNasKeys(tt.keys)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("unique =\n%v\nwant\n%v", got, tt.want)
			}
			if !reflect.DeepEqual(dups, tt.wantDups) {
				t.Errorf("duplicates =\n%v\nwant\n%v", dups, tt.wantDups)
			}
		})
	}
}
