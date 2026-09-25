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
	now := float64(time.Now().UnixMicro() / 1000000)
	stale := now - globalMeta.getPhoneInAtLeast() - 1
	for _, test := range []struct {
		name string
		// What pfconfig replies, and how long ago the process last had a reply confirming
		// which expiration pfconfig is at
		response string
		reloaded float64
		// What the refreshed object must be stamped with, what the process must compare it
		// against afterwards, and whether the two together make it valid
		marker float64
		global float64
		valid  bool
	}{
		{"new marker", `{"element":{"int":"eth1"},"last_touch_cache":200}`, stale, 200, 200, true},
		// A reply that crossed a newer one carries an older marker. Only the resource it
		// carries goes back to pfconfig, the ones stamped with the newer one stay valid
		{"crossed marker", `{"element":{"int":"eth1"},"last_touch_cache":50}`, now, 50, 100, false},
		{"missing marker", `{"element":{"int":"eth1"}}`, now, 100, 100, true},
		// A reply without a marker doesn't tell us which expiration pfconfig is at, so it
		// cannot pass for a confirmation that what we have is still current either
		{"missing marker does not confirm freshness", `{"element":{"int":"eth1"}}`, stale, 100, 100, false},
	} {
		t.Run(test.name, func(t *testing.T) {
			globalMeta.setLastTouchCache(100)
			globalMeta.setReloadedTouchCache(test.reloaded)
			object := &ManagementNetwork{Int: "eth0", Ip: "192.0.2.1", PfconfigNS: "interfaces::management_network(test)"}
			servePfconfigResponse(t, test.response)
			if err := FetchDecodeSocket(ctx, object); err != nil {
				t.Fatal(err)
			}
			if object.Int != "eth1" || object.Ip != "" || object.PfconfigNS != "interfaces::management_network(test)" {
				t.Errorf("refresh did not replace the payload and preserve query metadata: %#v", object)
			}
			if object.GetLoadedTouchCache() != test.marker {
				t.Errorf("refreshed object carries %v instead of its response's validity marker %v", object.GetLoadedTouchCache(), test.marker)
			}
			if globalMeta.getLastTouchCache() != test.global {
				t.Errorf("the response left %v as the value to compare against instead of %v", globalMeta.getLastTouchCache(), test.global)
			}
			if IsValid(ctx, object) != test.valid {
				t.Errorf("refreshed object validity is %v instead of %v", !test.valid, test.valid)
			}
		})
	}
}

// pfconfig only ever moves its last touch cache forward, so an older value means two fetches
// crossed rather than an expiration. Adopting it would send every resource stamped with the
// newer value back to pfconfig at once, but a value that a second reply reports is the real one.
func TestPublishLastTouchCacheHoldsBackACrossedReply(t *testing.T) {
	preservePfconfigMetadata(t)
	globalMeta.setLastTouchCache(200)

	if globalMeta.publishLastTouchCache(100) {
		t.Error("a reply carrying an older last touch cache should not be kept")
	}
	if globalMeta.getLastTouchCache() != 200 {
		t.Error("a reply carrying an older last touch cache replaced the one we have")
	}

	if !globalMeta.publishLastTouchCache(300) {
		t.Error("a reply carrying a newer last touch cache should be kept")
	}
	if globalMeta.getLastTouchCache() != 300 {
		t.Error("a reply carrying a newer last touch cache was not kept")
	}

	// pfconfig itself went backwards: every reply from now on reports the older value
	globalMeta.publishLastTouchCache(100)
	if !globalMeta.publishLastTouchCache(100) {
		t.Error("a last touch cache reported twice should be kept")
	}
	if globalMeta.getLastTouchCache() != 100 {
		t.Error("the process never adopts the value pfconfig keeps reporting")
	}
}

func TestFetchDecodeSocketKeysResponseMarker(t *testing.T) {
	preservePfconfigMetadata(t)
	// Set the value the mock reply is compared against, like the other marker tests do:
	// whatever a test run before this one left behind must not reject the reply as crossed
	globalMeta.setLastTouchCache(100)
	servePfconfigResponse(t, `{"keys":["general"],"last_touch_cache":200}`)
	object := &PfconfigKeys{PfconfigNS: "config::Pf"}
	if err := FetchDecodeSocket(ctx, object); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(object.Keys, []string{"general"}) || object.GetLoadedTouchCache() != 200 || !IsValid(ctx, object) {
		t.Errorf("keys response did not preserve its marker: %#v", object)
	}
}
