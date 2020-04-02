package tryableonce

import (
	"sync"
	"testing"
)

type one int

func (o *one) Increment() error {
	*o++
	return nil
}

func run(t *testing.T, once *TryableOnce, o *one, c chan bool) {
	once.Do(func() error { return o.Increment() })
	if v := *o; v != 1 {
		t.Errorf("once failed inside run: %d is not 1", v)
	}
	c <- true
}

func TestOnce(t *testing.T) {
	o := new(one)
	once := new(TryableOnce)
	c := make(chan bool)
	const N = 10
	for i := 0; i < N; i++ {
		go run(t, once, o, c)
	}
	for i := 0; i < N; i++ {
		<-c
	}
	if *o != 1 {
		t.Errorf("once failed outside run: %d is not 1", *o)
	}
}

func BenchmarkOnce(b *testing.B) {
	var once sync.Once
	f := func() {}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			once.Do(f)
		}
	})
}

func BenchmarkTryableOnce(b *testing.B) {
	var once TryableOnce
	f := func() error { return nil }
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			once.Do(f)
		}
	})
}
