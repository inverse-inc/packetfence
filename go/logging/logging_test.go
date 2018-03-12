package logging

import (
	"context"
	log "github.com/inconshreveable/log15"
	"testing"
)

var ctx = NewContext(context.Background())
var params = []interface{}{"test", "test", "test2", "test2"}

func BenchmarkLoggerWithAccessor(b *testing.B) {
	for i := 0; i < b.N; i++ {
		Logger(ctx)
	}
}

func BenchmarkLoggerWithAccessorAndParams(b *testing.B) {
	for i := 0; i < b.N; i++ {
		Logger(ctx, params...)
	}
}

func BenchmarkLoggerWithAccessorInfo(b *testing.B) {
	l := Logger(ctx, params...)
	l.SetHandler(log.DiscardHandler())
	for i := 0; i < b.N; i++ {
		l.Info("yes hello")
	}
}

func BenchmarkUnmodifiedLog15(b *testing.B) {
	for i := 0; i < b.N; i++ {
		srvlog.New()
	}
}

func BenchmarkUnmodifiedLog15WithParams(b *testing.B) {
	for i := 0; i < b.N; i++ {
		srvlog.New(params...)
	}
}

func BenchmarkUnmodifiedLog15Info(b *testing.B) {
	l := srvlog.New(params...)
	l.SetHandler(log.DiscardHandler())
	for i := 0; i < b.N; i++ {
		l.Info("yes hello")
	}
}
