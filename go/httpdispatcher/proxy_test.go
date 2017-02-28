package httpdispatcher

import (
	"net/http"
	"net/url"
	"os"
	"testing"
)

func TestMain(m *testing.M) {
	proxy := newProxy("")
	go proxy.run("8888")
	os.Exit(m.Run())
}

func TestLocalhost(t *testing.T) {
	resp, err := http.Get("http://localhost:8888")
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("Received non-403 response: %d\n", resp.StatusCode)
	}
}

func TestSimpleForward(t *testing.T) {
	client := &http.Client{}
	req, _ := http.NewRequest("GET", "http://localhost:8888", nil)
	req.Host = "www.packetfence.org"
	resp, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("Received non-200 response: %d\n", resp.StatusCode)
	}
}

func TestSimpleBlacklist(t *testing.T) {
	client := &http.Client{}
	req, _ := http.NewRequest("GET", "http://localhost:8888", nil)
	req.Host = "127.0.0.1"
	resp, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("Received non-404 response: %d\n", resp.StatusCode)
	}
}
