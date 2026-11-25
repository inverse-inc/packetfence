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
	value      V
	insertedAt int64
}

type writeRequest[K comparable, V any] struct {
	value V
	key   K
	op    opType
}

type shard[K comparable, V any] struct {
	items   map[K]cacheItem[V]
	writeCh chan writeRequest[K, V]
	sync.RWMutex
}

type (
	HashFunc[K comparable]            func(key K) uint64
	ShardedCache[K comparable, V any] struct {
		stopCh    chan struct{}
		hashFunc  HashFunc[K]
		shards    []*shard[K, V]
		wg        sync.WaitGroup
		Hits      uint64
		Misses    uint64
		stopOnce  sync.Once
		numShards uint32
	}
)

func HashString(key string) uint64 {
	h := uint64(14695981039346656037) // FNV-1a
	for i := 0; i < len(key); i++ {
		h = (h ^ uint64(key[i])) * 1099511628211
	}
	return h
}

func nextPowerOfTwo(v uint32) uint32 {
	if v == 0 {
		return 1
	}
	return 1 << bits.Len32(v-1)
}

func NewShardedCache[K comparable, V any](numShards, bufferSize int, hashFunc HashFunc[K]) *ShardedCache[K, V] {
	if numShards <= 0 {
		numShards = 1
	} else if numShards > 256 { // above 256 is not worth it
		numShards = 256
	} else { // use only power of 2
		numShards = int(nextPowerOfTwo(uint32(numShards)))
	}
	if bufferSize < 32 {
		bufferSize = 32
	} else if bufferSize > 4096 {
		bufferSize = 4096
	} else {
		bufferSize = int(nextPowerOfTwo(uint32(bufferSize)))
	}
	cache := &ShardedCache[K, V]{
		shards:    make([]*shard[K, V], numShards),
		numShards: uint32(numShards),
		stopCh:    make(chan struct{}),
		hashFunc:  hashFunc,
	}
	cache.wg.Add(numShards)
	for i := 0; i < numShards; i++ {
		s := &shard[K, V]{
			items:   make(map[K]cacheItem[V], 32),
			writeCh: make(chan writeRequest[K, V], bufferSize),
		}
		cache.shards[i] = s
		go cache.worker(s)
	}
	//go cache.janitor()
	return cache
}

func (c *ShardedCache[K, V]) getShardIndex(key K) uint64 {
	return c.hashFunc(key) & uint64(c.numShards-1)
}

func (c *ShardedCache[K, V]) SetAsync(ctx context.Context, key K, value V) error {
	req := writeRequest[K, V]{op: opSet, key: key, value: value}
	select {
	case c.shards[c.getShardIndex(key)].writeCh <- req:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (c *ShardedCache[K, V]) Set(ctx context.Context, key K, value V) error {
	s := c.shards[c.getShardIndex(key)]
	s.Lock()
	defer s.Unlock()
	s.items[key] = cacheItem[V]{value: value, insertedAt: time.Now().Unix()}
	return nil
}

func (c *ShardedCache[K, V]) DeleteAsync(ctx context.Context, key K) error {
	req := writeRequest[K, V]{op: opDelete, key: key}
	select {
	case c.shards[c.getShardIndex(key)].writeCh <- req:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (c *ShardedCache[K, V]) Delete(ctx context.Context, key K) error {
	s := c.shards[c.getShardIndex(key)]
	s.Lock()
	defer s.Unlock()
	delete(s.items, key)
	return nil
}

func (c *ShardedCache[K, V]) Get(key K) (V, bool) {
	s := c.shards[c.getShardIndex(key)]
	s.RLock()
	defer s.RUnlock()
	var zero V
	item, exists := s.items[key]
	if !exists {
		atomic.AddUint64(&c.Misses, 1)
		return zero, false
	}
	atomic.AddUint64(&c.Hits, 1)
	return item.value, true
}

func (c *ShardedCache[K, V]) worker(s *shard[K, V]) {
	defer c.wg.Done()
	for req := range s.writeCh {
		s.Lock()
		switch req.op {
		case opSet:
			s.items[req.key] = cacheItem[V]{value: req.value, insertedAt: time.Now().Unix()}
		case opDelete:
			delete(s.items, req.key)
		}
		s.Unlock()
	}
}

func (c *ShardedCache[K, V]) Close() {
	c.stopOnce.Do(func() {
		for _, s := range c.shards {
			close(s.writeCh)
		}
		close(c.stopCh)
		c.wg.Wait()
	})
}
