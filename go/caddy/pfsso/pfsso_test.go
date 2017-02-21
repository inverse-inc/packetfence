package pfsso

import (
	"context"
	"github.com/fingerbank/processor/log"
	"github.com/fingerbank/processor/sharedutils"
	"testing"
)

var ctx = log.LoggerNewContext(context.Background())
var pfsso, err = buildPfssoHandler(ctx)

func BenchmarkReadConfig(b *testing.B) {
	sharedutils.CheckError(err)
	for i := 0; i < b.N; i++ {
		readConfig(ctx, &pfsso, false)
	}
}

func BenchmarkReadConfigFirstLoad(b *testing.B) {
	sharedutils.CheckError(err)
	for i := 0; i < b.N; i++ {
		readConfig(ctx, &pfsso, true)
	}
}
