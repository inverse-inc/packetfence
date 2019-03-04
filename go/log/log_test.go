package log

import (
	"context"
	"github.com/cevaris/ordered_map"
	log "github.com/inconshreveable/log15"
	"testing"
)

func init() {
	ProcessName = "log-testing"
}

type TestLoggerContainer struct {
	elements []string
}

func (tlc *TestLoggerContainer) add(msg string) {
	tlc.elements = append(tlc.elements, msg)
}

func testLogger(ctx context.Context) (context.Context, *TestLoggerContainer) {
	tlc := &TestLoggerContainer{}
	ctx = LoggerNewContext(ctx)
	ctx = LoggerAddHandler(ctx, func(r *log.Record) error {
		tlc.add(r.Msg)
		return nil
	})
	return ctx, tlc
}

func TestTestLogger(t *testing.T) {
	msg := "testing1234"
	ctx, tlc := testLogger(context.Background())
	LoggerWContext(ctx).Info(msg)
	if tlc.elements[0] != msg {
		t.Error("test logger isn't logging to the testing backend")
	}
}

func TestLeveledLogger(t *testing.T) {
	msg := "testing1234"
	ctx, tlc := testLogger(context.Background())

	ctx = LoggerSetLevel(ctx, "info")
	LoggerWContext(ctx).Debug(msg)
	if len(tlc.elements) > 0 {
		t.Error("Debug message was logged although the level is info")
	}

	ctx = LoggerSetLevel(ctx, "debug")
	LoggerWContext(ctx).Debug(msg)
	if tlc.elements[0] != msg {
		t.Error("Debug message wasn't logged although the level is debug")
	}
}

func TestLoggerDebugFunc(t *testing.T) {
	msg := "testing1234"
	ctx, tlc := testLogger(context.Background())

	ctx = LoggerSetLevel(ctx, "info")
	LoggerDebugFunc(ctx, func() string {
		return msg
	})
	if len(tlc.elements) > 0 {
		t.Error("Debug message was logged although the level is info")
	}

	ctx = LoggerSetLevel(ctx, "debug")
	LoggerDebugFunc(ctx, func() string {
		return msg
	})
	if tlc.elements[0] != msg {
		t.Error("Debug message wasn't logged although the level is debug")
	}
}

func TestLoggerNewRequest(t *testing.T) {
	ctx, _ := testLogger(context.Background())
	ctx = LoggerNewRequest(ctx)

	uuidInt := ctx.Value(RequestUuidKey)

	if uuidInt == nil {
		t.Error("can't find request id in the context after calling LoggerNewRequest")
	}

	uuid := uuidInt.(string)
	if uuid == "" {
		t.Error("UUID that was generated is empty")
	}
}

func TestAddToLogContext(t *testing.T) {
	testKey := "testkey"
	testVal := "testVal"

	ctx, _ := testLogger(context.Background())
	changedCtx := AddToLogContext(ctx, testKey, testVal)
	elements := changedCtx.Value(AdditionnalLogElementsKey).(*ordered_map.OrderedMap)
	if v, ok := elements.Get(testKey); ok {
		if v != testVal {
			t.Error("additionnal element value is not equal to the one that was set")
		}
	} else {
		t.Error("Additionnal element that was added isn't part of the elements")
	}

	// Original ctx shouldn't have been touched
	elements = ctx.Value(AdditionnalLogElementsKey).(*ordered_map.OrderedMap)
	if _, ok := elements.Get(testKey); ok {
		t.Error("key was written to context that shouldn't have been changed (original one)")
	}
}

func TestDie(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			if r != "die" {
				t.Error("Die didn't die with the right message")
			}
		} else {
			t.Error("Die didn't die properly")
		}
	}()
	Die("die")
}
