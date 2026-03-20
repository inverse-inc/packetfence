package db

import (
	"hash/fnv"
	"sync"
)

type ShardedCacheShard[V any] struct {
	mu    sync.Mutex
	cache map[string]V
}

type ShardedCache[V any] struct {
	shards []ShardedCacheShard[V]
}

func NewShardedCache[V any](numShards int) *ShardedCache[V] {
	if numShards <= 0 {
		numShards = 1
	}
	sc := &ShardedCache[V]{
		shards: make([]ShardedCacheShard[V], numShards),
	}
	for i := range sc.shards {
		sc.shards[i].cache = make(map[string]V)
	}
	return sc
}

func (sc *ShardedCache[V]) Shard(key string) *ShardedCacheShard[V] {
	h := fnv.New32a()
	h.Write([]byte(key))
	return &sc.shards[h.Sum32()%uint32(len(sc.shards))]
}

func (s *ShardedCacheShard[V]) Get(key string) (V, bool) {
	v, ok := s.cache[key]
	return v, ok
}

func (s *ShardedCacheShard[V]) Set(key string, val V) {
	s.cache[key] = val
}

func (s *ShardedCacheShard[V]) Lock() {
	s.mu.Lock()
}

func (s *ShardedCacheShard[V]) Unlock() {
	s.mu.Unlock()
}
