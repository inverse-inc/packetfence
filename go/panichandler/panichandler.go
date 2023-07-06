package panichandler

import (
	"context"
	"fmt"
	"github.com/inverse-inc/go-utils/log"
	"net/http"
	"os"
	"runtime/debug"
)

// The body of the reply that is sent when a panic is recovered when handling panics in HTTP driven processes
const httpErrorMsg = "An internal error has occured, please check server side logs for details."

// Defered panic handler that will write an error into the HTTP body and call outputPanic
func Http(ctx context.Context, w http.ResponseWriter) {
	if r := recover(); r != nil {
		outputPanic(ctx, r)
		http.Error(w, httpErrorMsg, http.StatusInternalServerError)
	}
}

// Defered panic handler that calls outputPanic
func Standard(ctx context.Context) {
	if r := recover(); r != nil {
		outputPanic(ctx, r)
	}
}

// Output a panic error message along with its stacktrace
// The stacktrace will start from this function up to where the panic was initially called
// The stack and message are outputted in STDERR and a log line is added in Error
func outputPanic(ctx context.Context, recovered interface{}) {
	msg := fmt.Sprintf("Recovered panic: %s.", recovered)
	log.LoggerWContext(ctx).Error(msg)
	fmt.Fprintln(os.Stderr, msg)
	debug.PrintStack()
}
