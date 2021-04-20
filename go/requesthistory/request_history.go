package requesthistory

import (
	"errors"
	"github.com/inconshreveable/log15"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"sync"
)

type RequestHistory struct {
	container       []*Request
	uuidMap         map[string]int
	currentPosition int
	lock            *sync.RWMutex
}

func NewRequestHistory(size int) (RequestHistory, error) {
	if size <= 0 {
		return RequestHistory{}, errors.New("Size can't be 0 or negative")
	}

	rh := RequestHistory{}
	rh.uuidMap = make(map[string]int)
	rh.container = make([]*Request, size, size)
	rh.currentPosition = 0

	rh.lock = &sync.RWMutex{}

	return rh, nil
}

func (rh *RequestHistory) Create(uuid string) (*Request, error) {
	rh.lock.Lock()
	defer rh.lock.Unlock()

	if rh.uuidIndexNoLock(uuid) != -1 {
		return nil, errors.New("An element with this UUID already exists")
	}

	var r *Request
	if r = rh.container[rh.currentPosition]; r != nil {
		delete(rh.uuidMap, r.RequestId)
		r.Reset()
	} else {
		r = NewRequest()
	}

	r.RequestId = uuid
	rh.container[rh.currentPosition] = r
	rh.uuidMap[uuid] = rh.currentPosition

	rh.currentPosition++
	if rh.currentPosition >= len(rh.container) {
		rh.currentPosition = 0
	}

	return r, nil
}

func (rh *RequestHistory) GetRequestByUuid(uuid string) (*Request, error) {
	rh.lock.RLock()
	defer rh.lock.RUnlock()

	if i := rh.uuidIndexNoLock(uuid); i != -1 {
		return rh.container[i], nil
	} else {
		return nil, errors.New("Cannot find a request for this UUID")
	}
}

// Returns the index at which to find the request for the UUID
// Returns -1 if the UUID is unknown
func (rh *RequestHistory) UuidIndex(uuid string) int {
	rh.lock.RLock()
	defer rh.lock.RUnlock()

	return rh.uuidIndexNoLock(uuid)
}

func (rh *RequestHistory) uuidIndexNoLock(uuid string) int {
	if i, ok := rh.uuidMap[uuid]; ok {
		return i
	} else {
		return -1
	}
}

func (rh *RequestHistory) Iterator() RequestHistoryIterator {
	return NewRequestHistoryIterator(rh, rh.currentPosition-1)
}

func (rh *RequestHistory) All() []*Request {
	result := make([]*Request, 0, 0)
	iterator := rh.Iterator()
	r := iterator.Next()
	for r != nil {
		result = append(result, r)
		r = iterator.Next()
	}
	return result
}

type RequestHistoryIterator struct {
	started bool
	start   int
	current int
	rh      *RequestHistory
}

func NewRequestHistoryIterator(rh *RequestHistory, startAt int) RequestHistoryIterator {
	if startAt < 0 {
		startAt = len(rh.container) + startAt
	}
	rhi := RequestHistoryIterator{start: startAt, current: startAt, rh: rh}
	return rhi
}

func (rhi *RequestHistoryIterator) Next() *Request {
	// The first time we don't touch the current position
	if rhi.started {
		rhi.current -= 1

		if rhi.current < 0 {
			rhi.current = len(rhi.rh.container) - 1
		}

		// If we're back on the start number, we're done here
		if rhi.current == rhi.start {
			return nil
		}
	} else {
		rhi.started = true
	}

	// When the current element is nil, then we're done
	if rhi.rh.container[rhi.current] == nil {
		return nil
	} else {
		return rhi.rh.container[rhi.current]
	}
}

type Request struct {
	RequestId string
	Messages  []string
	lock      *sync.Mutex
}

func NewRequest() *Request {
	r := &Request{}
	r.lock = &sync.Mutex{}
	return r
}

func (r *Request) Reset() {
	r.lock.Lock()
	defer r.lock.Unlock()

	r.RequestId = ""
	r.Messages = make([]string, 100, 100)
}

func (r *Request) AddMessage(message string) {
	r.lock.Lock()
	defer r.lock.Unlock()

	r.Messages = append(r.Messages, message)
}

func (rh *RequestHistory) HandleLogRecord(record *log15.Record) error {
	m, err := sharedutils.TupleToMap(record.Ctx)
	sharedutils.CheckError(err)

	// Early return if message is empty
	if record.Msg == "" {
		return nil
	}

	if requestUuid, ok := m[log.RequestUuidKey].(string); ok {
		var r *Request
		var err error
		if r, err = rh.GetRequestByUuid(requestUuid); err != nil {
			r, err = rh.Create(requestUuid)
			sharedutils.CheckError(err)
		}

		r.AddMessage(record.Msg)
	}

	return nil
}
