package main

import (
	"time"
)

type BandwidthAccountingRecord struct {
	Mac        string
	TimeBucket time.Time
	InBytes    uint64
	OutBytes   uint64
}
