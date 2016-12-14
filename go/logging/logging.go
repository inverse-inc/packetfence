package logging

import (
	"context"
	log "github.com/inconshreveable/log15"
	"github.com/nu7hatch/gouuid"
	"os"
	"strconv"
)

const requestUuidKey = "request-uuid"
const processPidKey = "pid"

var srvlog = initSrvlog()

// Init the srvlog (top level logger)
func initSrvlog() log.Logger {
	srvlog := log.New()
	srvlog.SetHandler(log.StreamHandler(os.Stderr, log.LogfmtFormat()))
	return srvlog
}

// Get the current logger for the request (includes the request UUID)
func Logger(ctx context.Context) log.Logger {
	return srvlog.New(requestUuidKey, ctx.Value(requestUuidKey).(string), processPidKey, ctx.Value(processPidKey).(string))
}

// Grab a context that includes a UUID of the request for logging purposes
func NewContext(ctx context.Context) context.Context {
	u, _ := uuid.NewV4()
	uStr := u.String()
	ctx = context.WithValue(ctx, requestUuidKey, uStr)
	ctx = context.WithValue(ctx, processPidKey, strconv.Itoa(os.Getpid()))
	return ctx
}
