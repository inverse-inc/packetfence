package pool

import (
	"context"
	"database/sql"
	"fmt"
	"sync"

	"gopkg.in/alexcesaro/statsd.v2"
)

// FreeMac is the Free Mac address constant
const FreeMac = "00:00:00:00:00:00"

// FakeMac is the Fake Mac address constant
const FakeMac = "ff:ff:ff:ff:ff:ff"

// Random ip constant
const Random = 1

// OldestReleased ip constant
const OldestReleased = 2

// Backend interface
type Backend interface {
	NewDHCPPool(ctx context.Context, capacity uint64, algorithm int, StatsdClient *statsd.Client)
	ReserveIPIndex(index uint64, mac string) (string, error)
	IsFreeIPAtIndex(index uint64) bool
	GetMACIndex(index uint64) (uint64, string, error)
	GetFreeIPIndex(mac string) (uint64, string, error)
	IndexInPool(index uint64) bool
	FreeIPsRemaining() uint64
	FreeIPIndex(index uint64) error
	Capacity() uint64
	GetDHCPPool() DHCPPool
	GetIssues(macs []string) ([]string, map[uint64]string)
	Listen() bool
}

// Creater function
type Creater func(context.Context, uint64, string, int, *statsd.Client, *sql.DB) (Backend, error)

var poolLookup = map[string]Creater{
	"memory": NewMemoryPool,
	"mysql":  NewMysqlPool,
}

// Create function
func Create(ctx context.Context, poolType string, capacity uint64, name string, algorithm int, StatsdClient *statsd.Client, sql *sql.DB) (Backend, error) {
	if creater, found := poolLookup[poolType]; found {
		return creater(ctx, capacity, name, algorithm, StatsdClient, sql)
	}

	return nil, fmt.Errorf("Pool of %s not found", poolType)
}

