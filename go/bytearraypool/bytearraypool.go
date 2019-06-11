package bytearraypool

import "sync"

type ByteArrayPool struct {
	arraySize int
	chanPool  chan []byte
	syncPool  sync.Pool
}

func NewByteArrayPool(poolSize, arraySize int) *ByteArrayPool {
	return &ByteArrayPool{
		chanPool:  make(chan []byte, poolSize),
		syncPool:  sync.Pool{},
		arraySize: arraySize,
	}
}

func (p *ByteArrayPool) Get() []byte {
	if b := p.getFromSyncPool(); b != nil {
		return b
	}

	select {
	case b := <-p.chanPool:
		return b
	default:
		return p.NewItem()
	}
}

func (p *ByteArrayPool) NewItem() []byte {
	return make([]byte, p.arraySize)
}

func (p *ByteArrayPool) Fill(fill int) {
	left := cap(p.chanPool) - len(p.chanPool)
	if fill > left {
		fill = left
	}

	for i := 0; i < fill; i++ {
		var b = p.getFromSyncPool()
		if b == nil {
			b = p.NewItem()
		}

		select {
		case p.chanPool <- b:
		default:
			return
		}
	}
}

func (p *ByteArrayPool) getFromSyncPool() []byte {
	if i := p.syncPool.Get(); i != nil {
		b, ok := i.([]byte)
		if ok {
			return b
		}
	}

	return nil
}

func (p *ByteArrayPool) Put(b []byte) {
	b = b[:]
	select {
	case p.chanPool <- b:
	default:
		p.syncPool.Put(b)
	}
}
