package panichandler

import (
	"context"
	"fmt"
	"github.com/fingerbank/processor/log"
	"net/http"
	"os"
	"runtime/debug"
)

func Http(ctx context.Context, w http.ResponseWriter) {
	if r := recover(); r != nil {
		outputPanic(ctx, r)
		http.Error(w, "An internal error has occured, please check server side logs for details.", http.StatusInternalServerError)
	}
}

func Standard(ctx context.Context) {
	if r := recover(); r != nil {
		outputPanic(ctx, r)
	}
}

func outputPanic(ctx context.Context, recovered interface{}) {
	msg := fmt.Sprintf("Recovered panic: %s.", recovered)
	log.LoggerWContext(ctx).Error(msg)
	fmt.Fprintln(os.Stderr, msg)
	debug.PrintStack()
}
