package main

import (
	"github.com/inverse-inc/packetfence/go/mac"
	"sync"
	"time"
)

type SessionID [16]byte

type NodeKey struct {
	TenantId int
	Mac      mac.Mac
}

type Node struct {
	Sessions *Sessions
}

func (n *Node) GetBucket(sessionID SessionID, timeBucket time.Time) (BandwidthBucket, bool) {
	return n.Sessions.GetBucket(sessionID, timeBucket)
}

func (n *Node) AddToTimeBucket(sessionID SessionID, timeBucket time.Time, in, out int64) {
	s := n.Sessions.getOrAdd(sessionID)
	s.Add(timeBucket, in, out)
}

func (n *Node) UpdateTimeBucket(sessionID SessionID, timeBucket time.Time, in, out int64) {
	s := n.Sessions.getOrAdd(sessionID)
	s.Update(timeBucket, in, out)
}

func (n *Node) RemoveSession(sessionID SessionID) *Session {
	return n.Sessions.RemoveSession(sessionID)
}

func NewNode() *Node {
	return &Node{Sessions: NewSessions()}
}

type TimeBucketKey struct {
	SessionID  SessionID
	TimeBucket int64
}

type Session struct {
	lock        sync.RWMutex
	LastUpdated time.Time
	Buckets     map[int64]BandwidthBucket
	Stopped     bool
}

func NewSession() *Session {
	return &Session{Buckets: make(map[int64]BandwidthBucket)}
}

func (s *Session) Add(timeBucket time.Time, in, out int64) {
	s.lock.Lock()
	key := timeBucket.UnixNano()
	b := s.Buckets[key]
	b.InBytes += in
	b.OutBytes += out
	s.Buckets[key] = b
	s.lock.Unlock()
}

func (s *Session) Update(timeBucket time.Time, in, out int64) {
	s.lock.Lock()
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
	s.lock.Unlock()
}

func (s *Session) GetBucket(timeBucket time.Time) (BandwidthBucket, bool) {
	key := timeBucket.UnixNano()
	var bb BandwidthBucket
	var found bool
	s.lock.RLock()
	bb, found = s.Buckets[key]
	s.lock.RUnlock()
	return bb, found
}

type Sessions struct {
	lock     sync.RWMutex
	Sessions map[SessionID]*Session
}

func NewSessions() *Sessions {
	return &Sessions{Sessions: make(map[SessionID]*Session)}
}

func (s *Sessions) getOrAdd(id SessionID) *Session {
	var item *Session
	var found bool
	s.lock.RLock()
	if item, found = s.Sessions[id]; !found {
		s.lock.RUnlock()
		s.lock.Lock()
		// Recheck if exist if not found add
		if item, found = s.Sessions[id]; !found {
			item = NewSession()
			s.Sessions[id] = item
		}
		s.lock.Unlock()
	} else {
		s.lock.RUnlock()
	}
	return item
}

func (s *Sessions) RemoveSession(id SessionID) *Session {
	var item *Session
	var found bool
	s.lock.Lock()
	if item, found = s.Sessions[id]; found {
		delete(s.Sessions, id)
	}
	s.lock.Unlock()
	if item != nil {
		item.lock.Lock() // Sync any changes before returning
		item.lock.Unlock()
	}
	return item
}

func (s *Sessions) Add(sessionID SessionID, timeBucket time.Time, in, out int64) {
	item := s.getOrAdd(sessionID)
	item.Add(timeBucket, in, out)
}

func (s *Sessions) Update(sessionID SessionID, timeBucket time.Time, in, out int64) {
	item := s.getOrAdd(sessionID)
	item.Update(timeBucket, in, out)
}

func (s *Sessions) GetBucket(sessionID SessionID, timeBucket time.Time) (BandwidthBucket, bool) {
	var item *Session
	var found bool
	s.lock.RLock()
	if item, found = s.Sessions[sessionID]; !found {
		s.lock.RUnlock()
		return BandwidthBucket{}, false
	}
	s.lock.RUnlock()
	return item.GetBucket(timeBucket)
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

type Nodes struct {
	lock  sync.RWMutex
	Nodes map[NodeKey]*Node
}

func NewNodes() *Nodes {
	return &Nodes{Nodes: make(map[NodeKey]*Node)}
}

func (n *Nodes) Add(tenantId int, mac mac.Mac, sessionID SessionID, timeBucket time.Time, in, out int64) {
	node := n.getOrAddNode(tenantId, mac)
	node.AddToTimeBucket(sessionID, timeBucket, in, out)
}

func (n *Nodes) Update(tenantId int, mac mac.Mac, sessionID SessionID, timeBucket time.Time, in, out int64) {
	node := n.getOrAddNode(tenantId, mac)
	node.UpdateTimeBucket(sessionID, timeBucket, in, out)
}

func (n *Nodes) getOrAddNode(tenantId int, mac mac.Mac) *Node {
	var item *Node
	var found bool
	key := NodeKey{TenantId: tenantId, Mac: mac}
	n.lock.RLock() //First try to get a read Only lock
	if item, found = n.Nodes[key]; !found {
		// Not Found drop read lock get write lock
		n.lock.RUnlock()
		n.lock.Lock()
		// Recheck if exist if not found add
		if item, found = n.Nodes[key]; !found {
			item = NewNode()
			n.Nodes[key] = item
		}
		n.lock.Unlock()
	} else {
		n.lock.RUnlock()
	}
	return item
}

func (n *Nodes) GetBucket(tenantId int, mac mac.Mac, sessionID SessionID, timeBucket time.Time) (BandwidthBucket, bool) {
	var node *Node
	var found bool
	key := NodeKey{TenantId: tenantId, Mac: mac}
	n.lock.RLock() //First try to get a read Only lock
	if node, found = n.Nodes[key]; !found {
		n.lock.RUnlock()
		return BandwidthBucket{}, false
	}
	n.lock.RUnlock()
	return node.GetBucket(sessionID, timeBucket)
}

func (n *Nodes) RemoveSession(tenantId int, mac mac.Mac, sessionID SessionID) *Session {
	var item *Node
	var found bool
	key := NodeKey{TenantId: tenantId, Mac: mac}
	n.lock.RLock() //First try to get a read Only lock
	if item, found = n.Nodes[key]; !found {
		return nil
	}

	return item.RemoveSession(sessionID)
}
