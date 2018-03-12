package statsd

import (
	"context"
	_statsd "gopkg.in/alexcesaro/statsd.v2"
)

type TimingInt interface {
	Send(string)
}

type DummyTiming struct {
}

func (dt DummyTiming) Send(bucket string) {}

func NewStatsDTiming(ctx context.Context) TimingInt {
	statsdClient := FromContext(ctx)
	if statsdClient != nil {
		return statsdClient.NewTiming()
	} else {
		return *&DummyTiming{}
	}
}

func WithContext(ctx context.Context, c *_statsd.Client) context.Context {
	return context.WithValue(ctx, "statsd-client", c)
}

func FromContext(ctx context.Context) *_statsd.Client {
	i := ctx.Value("statsd-client")
	if i != nil {
		return i.(*_statsd.Client)
	} else {
		return nil
	}
}
