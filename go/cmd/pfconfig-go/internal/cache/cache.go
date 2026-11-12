// Package cache implement a simple but very efficient async sharded cache in memory.
// It is a general purpose cache that delivers great performance on both read and write at scale.
package cache

import (
	"context"
	"math/bits"
	"sync"
	"sync/atomic"
	"time"
)

type opType int

const (
	opSet opType = iota
	opDelete
)

type cacheItem[V any] struct {
	value     V
	expiresAt int64
}

type writeRequest[V any] struct {
	value V
	key   string
	op    opType
	ttl   int64
}

type shard[V any] struct {
	items   map[string]cacheItem[V]
	writeCh chan writeRequest[V]
	sync.RWMutex
}

type ShardedCache[V any] struct {
	stopCh    chan struct{}
	shards    []*shard[V]
	wg        sync.WaitGroup
	Hits      uint64
	Misses    uint64
	stopOnce  sync.Once
	numShards uint32
}

func nextPowerOfTwo(v uint32) uint32 {
	if v == 0 {
		return 1
	}
	return 1 << bits.Len32(v-1)
}

func NewShardedCache[V any](numShards, bufferSize int) *ShardedCache[V] {
	if numShards <= 0 {
		numShards = 1
	} else if numShards > 256 { // above 256 is not worth it
		numShards = 256
	} else { // use only power of 2
		numShards = int(nextPowerOfTwo(uint32(numShards)))
	}
	if bufferSize < 128 {
		bufferSize = 128
	} else if bufferSize > 1024 {
		bufferSize = 1024
	} else {
		bufferSize = int(nextPowerOfTwo(uint32(bufferSize)))
	}
	cache := &ShardedCache[V]{
		shards:    make([]*shard[V], numShards),
		numShards: uint32(numShards),
		stopCh:    make(chan struct{}),
	}
	cache.wg.Add(numShards + 1)
	for i := 0; i < numShards; i++ {
		s := &shard[V]{
			items:   make(map[string]cacheItem[V], 64),
			writeCh: make(chan writeRequest[V], bufferSize),
		}
		cache.shards[i] = s
		go cache.worker(s)
	}
	go cache.janitor()
	return cache
}

func fastHash(key string) uint64 {
	h := uint64(14695981039346656037) // FNV-1a
	for i := 0; i < len(key); i++ {
		h = (h ^ uint64(key[i])) * 1099511628211
	}
	return h
}

func (c *ShardedCache[V]) getShardIndex(key string) uint64 {
	return fastHash(key) & uint64(c.numShards-1)
}

func (c *ShardedCache[V]) Set(ctx context.Context, key string, value V, ttlSeconds int64) error {
	req := writeRequest[V]{op: opSet, key: key, value: value, ttl: ttlSeconds}
	select {
	case c.shards[c.getShardIndex(key)].writeCh <- req:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (c *ShardedCache[V]) Delete(ctx context.Context, key string) error {
	req := writeRequest[V]{op: opDelete, key: key}
	select {
	case c.shards[c.getShardIndex(key)].writeCh <- req:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (c *ShardedCache[V]) Get(key string) (V, bool) {
	s := c.shards[c.getShardIndex(key)]
	s.RLock()
	defer s.RUnlock()
	var zero V
	item, exists := s.items[key]
	if !exists || time.Now().Unix() > item.expiresAt {
		atomic.AddUint64(&c.Misses, 1)
		return zero, false
	}
	atomic.AddUint64(&c.Hits, 1)
	return item.value, true
}

func (c *ShardedCache[V]) worker(s *shard[V]) {
	defer c.wg.Done()
	for req := range s.writeCh {
		s.Lock()
		switch req.op {
		case opSet:
			exp := time.Now().Unix() + req.ttl
			s.items[req.key] = cacheItem[V]{value: req.value, expiresAt: exp}
		case opDelete:
			delete(s.items, req.key)
		}
		s.Unlock()
	}
}

func (c *ShardedCache[V]) janitor() {
	defer c.wg.Done()
	var currentShard uint32 = 0
	for {
		select {
		case <-time.After(30 * time.Second):
			s := c.shards[currentShard]
			now := time.Now().Unix()
			s.Lock()
			for k, v := range s.items {
				if now > v.expiresAt {
					delete(s.items, k)
				}
			}
			s.Unlock()
			currentShard = (currentShard + 1) % c.numShards
		case <-c.stopCh:
			return
		}
	}
}

func (c *ShardedCache[V]) Close() {
	c.stopOnce.Do(func() {
		for _, s := range c.shards {
			close(s.writeCh)
		}
		close(c.stopCh)
		c.wg.Wait()
	})
}
