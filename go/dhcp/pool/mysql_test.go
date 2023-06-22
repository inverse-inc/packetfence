package pool

import (
	"context"
	"database/sql"
	"fmt"
	"testing"

	"github.com/inverse-inc/packetfence/go/db"
)

func TestInitializePool(t *testing.T) {
	ctx := context.Background()
	db, err := db.DbFromConfig(ctx)
	if err != nil {
		t.Fatalf("Cannot connect to database: %s", err.Error())
	}

	for _, i := range []uint64{254, 1000, 1001, maxBatch, maxBatch - 2, maxBatch*4 - 2} {
		t.Run(fmt.Sprintf("%d", i), func(t *testing.T) {
			testInitializePool(t, i, db)
		})
	}

}

func testInitializePool(t *testing.T, capacity uint64, db *sql.DB) {
	algo := Random
	backend, err := NewMysqlPool(ctx, capacity, "test_254", algo, nil, db)
	if err != nil {
		t.Fatalf("Cannot create backend: %s", err.Error())
	}

	count := uint64(0)
	db.QueryRow("SELECT COUNT(*) from dhcppool where pool_name = ?", "test_254").Scan(&count)
	if count != capacity {
		t.Fatalf("Count %d does not match %d", capacity, count)
	}

	_ = backend
}
