package pfconfigdriver

import (
	"bufio"
	"encoding/binary"
	"io"
	"net"
	"reflect"
	"testing"
	"time"
)

// Serve one real pfconfig socket response without requiring a running pfconfig.
func servePfconfigResponse(t *testing.T, response string) {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { listener.Close() })
	host, port, err := net.SplitHostPort(listener.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("PFCONFIG_PROTO", "tcp")
	t.Setenv("PFCONFIG_TCP_HOST", host)
	t.Setenv("PFCONFIG_TCP_PORT", port)
	done := make(chan error, 1)
	go func() {
		conn, err := listener.Accept()
		if err != nil {
			done <- err
			return
		}
		defer conn.Close()
		conn.SetDeadline(time.Now().Add(5 * time.Second))
		_, err = bufio.NewReader(conn).ReadString('\n')
		if err == nil {
			err = binary.Write(conn, binary.LittleEndian, uint32(len(response)))
		}
		if err == nil {
			_, err = io.WriteString(conn, response)
		}
		done <- err
	}()
	t.Cleanup(func() {
		listener.Close()
		if err := <-done; err != nil {
			t.Error(err)
		}
	})
}

func preservePfconfigMetadata(t *testing.T) {
	t.Helper()
	previousSummary := clusterSummary
	previousTouch := globalMeta.getLastTouchCache()
	previousReload := globalMeta.getReloadedTouchCache()
	clusterSummary = &ClusterSummary{}
	t.Cleanup(func() {
		clusterSummary = previousSummary
		globalMeta.setLastTouchCache(previousTouch)
		globalMeta.setReloadedTouchCache(previousReload)
	})
}

func TestFetchDecodeSocketPreservesConfigurationOnError(t *testing.T) {
	preservePfconfigMetadata(t)
	for _, test := range []struct {
		name     string
		object   PfconfigObject
		response string
	}{
		{"missing element", &ManagementNetwork{Int: "eth0"}, `{"error":"not found","last_touch_cache":200}`},
		{"scalar element", &ManagementNetwork{Int: "eth0"}, `{"element":"eth1","last_touch_cache":200}`},
		{"partial element", &ManagementNetwork{Int: "eth0", Ip: "192.0.2.1"}, `{"element":{"int":"eth1","ip":42},"last_touch_cache":200}`},
		{"malformed envelope", &ManagementNetwork{Int: "eth0"}, `{"element":`},
		{"empty reply", &ManagementNetwork{Int: "eth0"}, ``},
		{"invalid keys", &PfconfigKeys{PfconfigNS: "config::Pf", Keys: []string{"general"}}, `{"keys":42,"last_touch_cache":200}`},
		{"invalid array", &ListenInts{Element: []string{"eth0"}}, `{"element":["eth1",42],"last_touch_cache":200}`},
	} {
		t.Run(test.name, func(t *testing.T) {
			test.object.SetLoadedAt(time.Unix(10, 0))
			test.object.SetLoadedTouchCache(100)
			before := reflect.New(reflect.TypeOf(test.object).Elem())
			before.Elem().Set(reflect.ValueOf(test.object).Elem())
			globalMeta.setLastTouchCache(100)
			globalMeta.setReloadedTouchCache(10)
			servePfconfigResponse(t, test.response)
			if err := FetchDecodeSocket(ctx, test.object); err == nil {
				t.Fatal("expected a decoding error")
			}
			if !reflect.DeepEqual(test.object, before.Interface()) {
				t.Errorf("failed fetch changed the configuration: got %#v, want %#v", test.object, before.Interface())
			}
			if globalMeta.getLastTouchCache() != 100 || globalMeta.getReloadedTouchCache() != 10 {
				t.Error("failed fetch changed global validity metadata")
			}
		})
	}
}

func TestFetchDecodeSocketPublishesResponseMarker(t *testing.T) {
	preservePfconfigMetadata(t)
	for _, test := range []struct {
		name     string
		response string
		marker   float64
	}{
		{"new marker", `{"element":{"int":"eth1"},"last_touch_cache":200}`, 200},
		{"backward marker", `{"element":{"int":"eth1"},"last_touch_cache":50}`, 50},
		{"missing marker", `{"element":{"int":"eth1"}}`, 100},
	} {
		t.Run(test.name, func(t *testing.T) {
			globalMeta.setLastTouchCache(100)
			object := &ManagementNetwork{Int: "eth0", Ip: "192.0.2.1", PfconfigNS: "interfaces::management_network(test)"}
			servePfconfigResponse(t, test.response)
			if err := FetchDecodeSocket(ctx, object); err != nil {
				t.Fatal(err)
			}
			if object.Int != "eth1" || object.Ip != "" || object.PfconfigNS != "interfaces::management_network(test)" {
				t.Errorf("refresh did not replace the payload and preserve query metadata: %#v", object)
			}
			if object.GetLoadedTouchCache() != test.marker || !IsValid(ctx, object) {
				t.Error("refreshed object does not carry its response's validity marker")
			}
		})
	}
}

func TestFetchDecodeSocketKeysResponseMarker(t *testing.T) {
	preservePfconfigMetadata(t)
	servePfconfigResponse(t, `{"keys":["general"],"last_touch_cache":200}`)
	object := &PfconfigKeys{PfconfigNS: "config::Pf"}
	if err := FetchDecodeSocket(ctx, object); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(object.Keys, []string{"general"}) || object.GetLoadedTouchCache() != 200 || !IsValid(ctx, object) {
		t.Errorf("keys response did not preserve its marker: %#v", object)
	}
}
