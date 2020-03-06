package main

import (
	"github.com/inverse-inc/packetfence/go/mac"
	"sync"
	"time"
)

type SessionID [16]byte

type BucketKey struct {
	TenantId int
	Mac      mac.Mac
}

type TimeBucketKey struct {
	SessionID  SessionID
	TimeBucket int64
}

type Session struct {
	LastUpdated time.Time
	Buckets     map[int64]BandwidthBucket
}

func (s *Session) Add(timeBucket time.Time, in, out int64) {
	key := timeBucket.UnixNano()
	b := s.Buckets[key]
	b.InBytes += in
	b.OutBytes += out
	s.Buckets[key] = b
}

func (s *Session) Update(timeBucket time.Time, in, out int64) {
	key := timeBucket.UnixNano()
	bb := BandwidthBucket{InBytes: in, OutBytes: out}
	for k, v := range s.Buckets {
		if k == key {
			continue
		}
		bb.InBytes -= v.InBytes
		bb.OutBytes -= v.OutBytes
	}

	if bb.InBytes < 0 {
		bb.InBytes = 0
	}

	if bb.OutBytes < 0 {
		bb.OutBytes = 0
	}

	if bb.InBytes > 0 || bb.OutBytes > 0 {
		s.Buckets[key] = bb
	}
}

type BandwidthBucket struct {
	InBytes  int64
	OutBytes int64
}

type BandwidthBuckets struct {
	lock    sync.RWMutex
	Buckets map[TimeBucketKey]BandwidthBucket
}

func NewBandwidthBuckets() *BandwidthBuckets {
	return &BandwidthBuckets{Buckets: make(map[TimeBucketKey]BandwidthBucket)}
}

type Buckets struct {
	lock             sync.RWMutex
	BandwidthBuckets map[BucketKey]*BandwidthBuckets
}

func (b *Buckets) Add(tenantId int, mac mac.Mac, sessionID SessionID, timeBucket time.Time, in, out int64) {
	bb := b.getOrAdd(tenantId, mac, sessionID, timeBucket)
	bb.Add(sessionID, timeBucket, in, out)
}

func (b *Buckets) Update(tenantId int, mac mac.Mac, sessionID SessionID, timeBucket time.Time, in, out int64) {
	bb := b.getOrAdd(tenantId, mac, sessionID, timeBucket)
	bb.Update(sessionID, timeBucket, in, out)
}

func (b *Buckets) getOrAdd(tenantId int, mac mac.Mac, sessionID SessionID, timeBucket time.Time) *BandwidthBuckets {
	var bb *BandwidthBuckets
	var found bool
	key := BucketKey{TenantId: tenantId, Mac: mac}
	b.lock.RLock() //First try to get a read Only lock
	if bb, found = b.BandwidthBuckets[key]; !found {
		// Not Found drop read lock get write lock
		b.lock.RUnlock()
		b.lock.Lock()
		// Recheck if exist if not found add
		if bb, found = b.BandwidthBuckets[key]; !found {
			bb = NewBandwidthBuckets()
			b.BandwidthBuckets[key] = bb
		}
		b.lock.Unlock()
	} else {
		b.lock.RUnlock()
	}
	return bb
}

func (b *Buckets) GetBucket(tenantId int, mac mac.Mac, sessionID SessionID, timeBucket time.Time) (BandwidthBucket, bool) {
	var bb *BandwidthBuckets
	var found bool
	key := BucketKey{TenantId: tenantId, Mac: mac}
	b.lock.RLock() //First try to get a read Only lock
	if bb, found = b.BandwidthBuckets[key]; !found {
		b.lock.RUnlock()
		return BandwidthBucket{}, false
	}
	b.lock.RUnlock()
	return bb.GetBucket(sessionID, timeBucket)
}

func (b *BandwidthBuckets) GetBucket(sessionID SessionID, timeBucket time.Time) (BandwidthBucket, bool) {
	key := TimeBucketKey{SessionID: sessionID, TimeBucket: timeBucket.UnixNano()}
	b.lock.RLock()
	defer b.lock.RUnlock()
	bk, found := b.Buckets[key]
	return bk, found
}

func (b *BandwidthBuckets) Add(sessionID SessionID, timeBucket time.Time, in, out int64) {
	key := TimeBucketKey{SessionID: sessionID, TimeBucket: timeBucket.UnixNano()}
	b.lock.Lock()
	bb := b.Buckets[key]
	bb.InBytes += in
	bb.OutBytes += out
	b.Buckets[key] = bb
	b.lock.Unlock()
}

func (b *BandwidthBuckets) Update(sessionID SessionID, timeBucket time.Time, in, out int64) {
	key := TimeBucketKey{SessionID: sessionID, TimeBucket: timeBucket.UnixNano()}
	bb := BandwidthBucket{InBytes: in, OutBytes: out}
	b.lock.Lock()
	for k, v := range b.Buckets {
		if k.SessionID != key.SessionID || k.TimeBucket == key.TimeBucket {
			continue
		}
		bb.InBytes -= v.InBytes
		bb.OutBytes -= v.OutBytes
	}
	b.Buckets[key] = bb
	b.lock.Unlock()
}

func NewBuckets() *Buckets {
	return &Buckets{BandwidthBuckets: make(map[BucketKey]*BandwidthBuckets)}
}
