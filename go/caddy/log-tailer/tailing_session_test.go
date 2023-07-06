package logtailer

import (
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"testing"
	"time"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/jcuga/golongpoll"
)

func TestTailingSession(t *testing.T) {
	eventsManager, err := golongpoll.StartLongpoll(golongpoll.Options{
		LoggingEnabled: (sharedutils.EnvOrDefault("LOG_LEVEL", "") == "debug"),
	})
	sharedutils.CheckError(err)

	files := []string{"/usr/local/pf/logs/packetfence.log", "/var/log/messages"}

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
