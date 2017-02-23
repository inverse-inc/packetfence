package filter_client

import (
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
	cmd := exec.Command("perl", "-I", "/usr/local/pf/t", "-Msetup_test_config", "/usr/local/pf/sbin/pffilter", "-s", SOCK_PATH, "-n", "pffilter-test")
	err := cmd.Start()
	if err != nil {
		os.Exit(1)
		return
	}
	defer func() {
		cmd.Process.Signal(syscall.SIGINT)
		cmd.Process.Wait()
	}()
	time.Sleep(60000 * time.Millisecond)
	os.Exit(m.Run())
}
