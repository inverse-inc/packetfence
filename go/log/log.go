
package log

import (
	"context"
	"os"
	"strconv"
	"strings"

	"github.com/cevaris/ordered_map"
	"github.com/google/uuid"
	log "github.com/inconshreveable/log15"
	"github.com/inverse-inc/go-utils/sharedutils"
)

const RequestUuidKey = "request-uuid"
const ProcessPidKey = "pid"
const LoggerKey = "logger"
const LogLevel = "loglevel"

type PfLogger = log.Logger

const AdditionnalLogElementsKey = "additionnal-log-elements"

var ProcessName = os.Args[0]

// Structure that contains the necessary data to make this logger work
type LoggerStruct struct {
	logger     log.Logger
	handler    log.Handler
	inDebug    bool
	processPid string
	Level      string
}

// Set the ProcessName
func SetProcessName(Name string) {
	ProcessName = Name
}

// Create a new logger from an existing one with the same confiuration
func (l LoggerStruct) NewLogger() LoggerStruct {
	new := LoggerStruct{}
	new.logger = l.logger.New()
	new.handler = l.handler
	new.inDebug = l.inDebug
	new.processPid = l.processPid
	new.Level = l.Level

	return new
}

// Create a new LoggerStruct with its elements initialized
func newLoggerStruct() LoggerStruct {
	logger := LoggerStruct{}
	logger.logger = log.New()
	return logger
}

// Set the handler for the logger
// This should *only* be called to set the handler for the actual backend (syslog, file, ...) and not when leveling the handler as LoggerStruct.handler is the logger non-leveled handler
func (l *LoggerStruct) SetHandler(handler log.Handler) {
	l.handler = handler
	l.logger.SetHandler(l.handler)
}

// Set the level of a logger from a context
// This will Die/panic if the provided level is invalid
func LoggerSetLevel(ctx context.Context, levelStr string) context.Context {
	logger := loggerFromContext(ctx)
	logger.Level = levelStr

	levelStr = strings.ToLower(levelStr)

	if levelStr == "debug" {
		logger.inDebug = true
	} else {
		logger.inDebug = false
	}

	level, err := log.LvlFromString(levelStr)
	if err != nil {
		Die("Cannot find log level : " + levelStr)
	}
	leveledBackend := log.LvlFilterHandler(level, logger.handler)
	logger.logger.SetHandler(leveledBackend)
	ctx = context.WithValue(ctx, LoggerKey, logger)
	return ctx
}

// Get the level of a logger from a context
func LoggerGetLevel(ctx context.Context) string {
	logger := loggerFromContext(ctx)
	return logger.Level
}

// Add a handler to a logger in the context
func LoggerAddHandler(ctx context.Context, f func(*log.Record) error) context.Context {
	logger := loggerFromContext(ctx)
	loggerHandler := log.MultiHandler(logger.handler, log.FuncHandler(f))
	logger.SetHandler(loggerHandler)

	return context.WithValue(ctx, LoggerKey, logger)
}

// Initialize the logger in a context
func initContextLogger(ctx context.Context) context.Context {
	logger := newLoggerStruct()

	logger.SetHandler(getLogBackend())

	logger.processPid = strconv.Itoa(os.Getpid())

	ctx = context.WithValue(ctx, LoggerKey, logger)

	level := sharedutils.EnvOrDefault("LOG_LEVEL", "")
	if level != "" {
		//logger.logger.Info("Setting log level to " + level)
		ctx = LoggerSetLevel(ctx, level)
	}

	return ctx
}

// Get the logger from a context
// If the logger isn't there this will panic so make sure its there before calling this
func loggerFromContext(ctx context.Context) LoggerStruct {
	loggerInt := ctx.Value(LoggerKey)

	var logger LoggerStruct
	logger = loggerInt.(LoggerStruct)

	return logger
}

// Get a logger that isn't tied to any specific context
func Logger() log.Logger {
	return LoggerWContext(LoggerDummyContext())
}

// Get a logger initialized with the values from the context (pid, request id and additionnal elements)
func LoggerWContext(ctx context.Context, args ...interface{}) log.Logger {
	if l := ctx.Value(LoggerKey); l == nil {
		ctx = LoggerNewContext(ctx)
	}

	logger := loggerFromContext(ctx)

	loggerArgs := []interface{}{ProcessPidKey, logger.processPid}
	if requestUuid := ctx.Value(RequestUuidKey); requestUuid != nil {
		args = append(args, RequestUuidKey, requestUuid)
	}

	args = append(loggerArgs, args...)

	iter := ctx.Value(AdditionnalLogElementsKey).(*ordered_map.OrderedMap).IterFunc()
	for kv, ok := iter(); ok; kv, ok = iter() {
		args = append(args, kv.Key, kv.Value)
	}

	return logger.logger.New(args...)
}

// Get a logger dummy context (empty context)
func LoggerDummyContext() context.Context {
	ctx := context.Background()
	ctx = LoggerNewContext(ctx)
	return ctx
}

// Create a new logger in a context
// Will ensure that its initialized with the PID of the current process
func LoggerNewContext(ctx context.Context) context.Context {
	ctx = initContextLogger(ctx)
	ctx = context.WithValue(ctx, AdditionnalLogElementsKey, ordered_map.NewOrderedMap())
	return ctx
}

// Transfer the logger from a context to another
func TranferLogContext(sourceCtx context.Context, destCtx context.Context) context.Context {
	destCtx = context.WithValue(destCtx, LoggerKey, sourceCtx.Value(LoggerKey))
	destCtx = context.WithValue(destCtx, AdditionnalLogElementsKey, sharedutils.CopyOrderedMap(sourceCtx.Value(AdditionnalLogElementsKey).(*ordered_map.OrderedMap)))
	return destCtx
}

// Generate a new UUID for the current request and add it to the context
func LoggerNewRequest(ctx context.Context) context.Context {
	u, _ := uuid.NewUUID()
	uStr := u.String()
	ctx = context.WithValue(ctx, RequestUuidKey, uStr)
	return ctx
}

// Add custom fields to the context
// This supports a tuple for the args
//	ex: "mykey1", "myval1", "mykey2", "myval2"
func AddToLogContext(ctx context.Context, args ...interface{}) context.Context {
	m, err := sharedutils.TupleToOrderedMap(args)
	sharedutils.CheckError(err)

	additionnalLogElementsInt := ctx.Value(AdditionnalLogElementsKey)

	if additionnalLogElementsInt == nil {
		return ctx
	}

	additionnalLogElements := sharedutils.CopyOrderedMap(additionnalLogElementsInt.(*ordered_map.OrderedMap))

	iter := m.IterFunc()
	for kv, ok := iter(); ok; kv, ok = iter() {
		additionnalLogElements.Set(kv.Key, kv.Value)
	}

	return context.WithValue(ctx, AdditionnalLogElementsKey, additionnalLogElements)
}

// Logging helper that allows for lazy evaluation of debug statements
// The function f will only be executed if the current logger (in the context) is in debug
// The function f can also log statements on its own
// If an empty string is returned from f, it will not be logger
func LoggerDebugFunc(ctx context.Context, f func() string) {
	logger := loggerFromContext(ctx)
	if logger.inDebug {
		// Checking if returned non-empty string. Otherwise f already handled the necessary logging
		if msg := f(); msg != "" {
			LoggerWContext(ctx).Debug(msg)
		}
	}
}

// panic while logging a problem as critical
func Die(msg string, args ...interface{}) {
	Logger().Crit(msg, args...)
	panic(msg)
}
