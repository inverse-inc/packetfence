package filter_client

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"syscall"
	"testing"
	"time"
)

const SOCK_PATH = "/usr/local/pf/var/run/pffilter-test.sock"

func TestNotStarted(t *testing.T) {
	client := NewClientWithPath("/usr/local/pf/var/run/pffilter-test-garbage.sock")
	_, err := client.FilterProfile(map[string]interface{}{})

	if err == nil {
		t.Error("Did not handle service not started")
	}
}

func TestFilters(t *testing.T) {
	t.Run("FilterProfile", func(t *testing.T) {

		client := NewClientWithPath(SOCK_PATH)

		info, err := client.FilterProfile(map[string]interface{}{})

		if err != nil {
			t.Error(err)
			return
		}

		profile_name := info.(string)

		if profile_name != "default" {
			t.Errorf("Invalid profile name return")
		}
	})

	t.Run("FilterProfileNodeRole", func(t *testing.T) {

		client := NewClientWithPath(SOCK_PATH)

		info, err := client.FilterProfile(map[string]interface{}{
			"category": "bob",
		})

		if err != nil {
			t.Error(err)
			return
		}

		profile_name := info.(string)

		if profile_name != "node_role" {
			t.Errorf("Invalid profile name return")
		}
	})

	t.Run("FilterVlan", func(t *testing.T) {

		client := NewClientWithPath(SOCK_PATH)

		info, err := client.FilterVlan("RegistrationRole", map[string]interface{}{
			"ssid": "OPEN",
			"node_info": map[string]interface{}{
				"category": "default",
			},
		})

		if err != nil {
			t.Error(err)
			return
		}

		role := info.(string)

		if role != "registration" {
			t.Errorf("Invalid role return")
		}
	})
}

func BenchmarkProfileFilterSimple(b *testing.B) {
	client := NewClientWithPath(SOCK_PATH)
	for i := 0; i < b.N; i++ {
		client.FilterProfile(map[string]interface{}{"category": "default"})
	}
}

func TestMain(m *testing.M) {
	cmd := exec.Command("perl", "-I", "/usr/local/pf/t", "-Mtest_paths", "/usr/local/pf/sbin/pffilter", "-s", SOCK_PATH, "-n", "pffilter-test")
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	err := cmd.Start()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Cannot start pffilter: %s\n", err)
		os.Exit(1)
		return
	}

	exited := make(chan error, 1)
	go func() { exited <- cmd.Wait() }()

	// pffilter can take well over 20s to start when the machine is busy (go test ./... runs packages in parallel)
	if err := waitForSocket(SOCK_PATH, exited, 120*time.Second); err != nil {
		fmt.Fprintf(os.Stderr, "pffilter is not ready: %s\n", err)
		cmd.Process.Kill()
		os.Exit(1)
		return
	}

	result := m.Run()

	cmd.Process.Signal(syscall.SIGTERM)
	<-exited
	os.Exit(result)
}

func waitForSocket(path string, exited <-chan error, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for {
		conn, err := net.Dial("unix", path)
		if err == nil {
			conn.Close()
			return nil
		}

		if time.Now().After(deadline) {
			return fmt.Errorf("%s not accepting connections after %s: %w", path, timeout, err)
		}

		select {
		case err := <-exited:
			return fmt.Errorf("pffilter exited before %s was ready: %v", path, err)
		case <-time.After(500 * time.Millisecond):
		}
	}
}
