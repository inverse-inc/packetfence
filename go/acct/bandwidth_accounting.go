package main

import (
	"time"
)

type BandwidthAccountingRecord struct {
	TenantId   int32
	Mac        string
	TimeBucket time.Time
	InBytes    uint64
	OutBytes   uint64
}
