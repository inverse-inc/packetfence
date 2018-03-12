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
const additionnalLogElementsKey = "additionnal-log"

var srvlog = initSrvlog()

// Init the srvlog (top level logger)
func initSrvlog() log.Logger {
	srvlog := log.New()
	srvlog.SetHandler(log.StreamHandler(os.Stderr, log.LogfmtFormat()))
	return srvlog
}

// Get the current logger for the request (includes the request UUID)
func Logger(ctx context.Context, args ...interface{}) log.Logger {
	loggerArgs := []interface{}{processPidKey, ctx.Value(processPidKey).(string), requestUuidKey, ctx.Value(requestUuidKey).(string)}
	args = append(loggerArgs, args...)

	additionnalLogElements := ctx.Value(additionnalLogElementsKey).(map[interface{}]interface{})
	for k, v := range additionnalLogElements {
		args = append(args, k, v)
	}

	return srvlog.New(args...)
}

// Grab a context that includes a UUID of the request for logging purposes
func NewContext(ctx context.Context) context.Context {
	u, _ := uuid.NewV4()
	uStr := u.String()
	ctx = context.WithValue(ctx, requestUuidKey, uStr)
	ctx = context.WithValue(ctx, processPidKey, strconv.Itoa(os.Getpid()))
	ctx = context.WithValue(ctx, additionnalLogElementsKey, make(map[interface{}]interface{}))
	return ctx
}

func AddToLogContext(ctx context.Context, args ...interface{}) context.Context {
	var key interface{}
	additionnalLogElements := ctx.Value(additionnalLogElementsKey).(map[interface{}]interface{})
	for i, o := range args {
		if i%2 == 1 {
			additionnalLogElements[key] = o
		} else {
			key = o
		}
	}
	context.WithValue(ctx, additionnalLogElementsKey, additionnalLogElements)
	return ctx
}
