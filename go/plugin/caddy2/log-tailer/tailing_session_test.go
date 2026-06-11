package logtailer

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/jcuga/golongpoll"
)

func IsDebian() bool {
	file, err := os.Open("/etc/os-release")
	if err != nil {
		return false
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()

		// Look for ID=debian or ID_LIKE=...debian...
		if strings.HasPrefix(line, "ID=") || strings.HasPrefix(line, "ID_LIKE=") {
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				// Clean up any quotes
				val := strings.Trim(parts[1], "\"")
				if strings.Contains(val, "debian") {
					return true
				}
			}
		}
	}
	return false
}

func TestTailingSession(t *testing.T) {
	eventsManager, err := golongpoll.StartLongpoll(golongpoll.Options{
		LoggingEnabled: (sharedutils.EnvOrDefault("LOG_LEVEL", "") == "debug"),
	})
	sharedutils.CheckError(err)

	var files []string
	if IsDebian() {
		files = []string{"/usr/local/pf/logs/packetfence.log", "/var/log/syslog"}
	} else {
		files = []string{"/usr/local/pf/logs/packetfence.log", "/var/log/messages"}
	}

	ts := NewTailingSession(files, regexp.MustCompile(`.*`))
	ts.Start("test", eventsManager)

	pid := os.Getpid()

	for _, file := range files {
		err = exec.Command("/bin/bash", "-c", fmt.Sprintf("lsof -p %d | grep %s", pid, file)).Run()
		if err != nil {
			t.Errorf("File %s has not been opened for reading", file)
		}
	}

	ts.Stop()
	time.Sleep(1 * time.Second)

	for _, file := range files {
		err = exec.Command("/bin/bash", "-c", fmt.Sprintf("lsof -p %d | grep %s", pid, file)).Run()
		if err == nil {
			t.Errorf("File %s has not been closed for reading", file)
		}
	}

}
