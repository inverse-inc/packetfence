package cos

import (
	"context"
	"os"
	"os/signal"
	"time"
)

//InterruptContext returns a context which is
//cancelled on OS Interrupt
func InterruptContext() context.Context {
	return InterruptContextFrom(context.Background())
}

//InterruptContextFrom returns a context derived from the given parent context
//which is cancelled on OS Interrupt
func InterruptContextFrom(parent context.Context) context.Context {
	ctx, cancel := context.WithCancel(parent)
	go func() {
		sig := make(chan os.Signal, 1)
		signal.Notify(sig, os.Interrupt) //windows compatible?
		<-sig
		signal.Stop(sig)
		cancel()
	}()
	return ctx
}

//SleepSignal sleeps for the given duration,
//or until a SIGHUP is received
func SleepSignal(d time.Duration) {
	<-AfterSignal(d)
}
