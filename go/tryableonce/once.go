package tryableonce

import (
	"errors"
	"runtime"
	"sync/atomic"
)

type TryableOnce struct {
	done uint32
}

var Retry = errors.New("Retry")

func (o *TryableOnce) Do(f func() error) error {
	for {
		if o.done == 2 {
			return nil
		}

		if atomic.CompareAndSwapUint32(&o.done, 0, 1) {
			err := f()
			if err != nil {
				atomic.StoreUint32(&o.done, 0)
			} else {
				atomic.StoreUint32(&o.done, 2)
			}
			return err
		}

		switch atomic.LoadUint32(&o.done) {
		case 0:
			return Retry
		case 1:
			runtime.Gosched()
		case 2:
			return nil
		}
	}

}
