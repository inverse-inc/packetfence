// +build !windows

package log

import (
	"log/syslog"
	"os"

	"github.com/inconshreveable/log15"
	"github.com/inverse-inc/go-utils/sharedutils"
)

func getLogBackend() log15.Handler {
	output := sharedutils.EnvOrDefault("LOG_OUTPUT", "syslog")
	if output == "syslog" {
		syslogBackend, err := log15.SyslogHandler(syslog.LOG_INFO, ProcessName, log15.LogfmtFormat())
		sharedutils.CheckError(err)
		return syslogBackend
	} else {
		return log15.StreamHandler(os.Stdout, log15.LogfmtFormat())
	}
}
