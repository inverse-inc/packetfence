package pool

import (
	"context"
	"testing"

	"github.com/inverse-inc/packetfence/go/db"
)

func BenchmarkInitializePool254(b *testing.B) {
	ctx := context.Background()
	db, _ := db.DbFromConfig(ctx)
	for n := 0; n < b.N; n++ {
		_, _ = NewMysqlPool(ctx, 254, "bench_254", Random, nil, db)
	}
}

func BenchmarkInitializePool65534(b *testing.B) {
	ctx := context.Background()
	db, _ := db.DbFromConfig(ctx)
	for n := 0; n < b.N; n++ {
		_, _ = NewMysqlPool(ctx, 65534, "bench_65534", Random, nil, db)
	}
}
