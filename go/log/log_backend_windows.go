// +build windows

package log

import (
	"os"

	"github.com/inconshreveable/log15"
)

func getLogBackend() log15.Handler {
	return log15.StreamHandler(os.Stdout, log15.LogfmtFormat())
}
