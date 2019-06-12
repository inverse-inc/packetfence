package bytearraypool

import "sync"

// ByteArrayPool caches at most N []byte of M size.
type ByteArrayPool struct {
	arraySize int
	chanPool  chan []byte
	syncPool  sync.Pool
}

// NewByteArrayPool create a *ByteArrayPool 
func NewByteArrayPool(maxSize, arraySize int) *ByteArrayPool {
	return &ByteArrayPool{
		chanPool:  make(chan []byte, maxSize),
		syncPool:  sync.Pool{},
		arraySize: arraySize,
	}
}

// Get gets a previously cached []byte or create a new one
func (p *ByteArrayPool) Get() []byte {
	if b := p.getFromSyncPool(); b != nil {
		return b
	}

	select {
	case b := <-p.chanPool:
		return b
	default:
		return p.newItem()
	}
}

// newItem createa a new []byte
func (p *ByteArrayPool) newItem() []byte {
	return make([]byte, p.arraySize)
}

// Fill fills the ByteArrayPool with N number of []byte
func (p *ByteArrayPool) Fill(fill int) {
	left := cap(p.chanPool) - len(p.chanPool)
	if fill > left {
		fill = left
	}

	for i := 0; i < fill; i++ {
		var b = p.getFromSyncPool()
		if b == nil {
			b = p.newItem()
		}

		select {
		case p.chanPool <- b:
		default:
			return
		}
	}
}

// getFromSyncPool get a []byte from the overflow pool
func (p *ByteArrayPool) getFromSyncPool() []byte {
	if i := p.syncPool.Get(); i != nil {
		b, ok := i.([]byte)
		if ok {
			return b
		}
	}

	return nil
}

// Put put a []byte in the pool must no longer be referenced
func (p *ByteArrayPool) Put(b []byte) {
	b = b[:]
	select {
	case p.chanPool <- b:
	default:
		p.syncPool.Put(b)
	}
}
