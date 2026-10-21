package pfqueueclient

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
)

const (
	testQueue     = "Queue:pfdhcplistener_000"
	testTaskID    = "Task:6E8A09A2-A086-11F1-8B96-8345D4E48283:Queue:pfdhcplistener:api:process_dhcpv4"
	testCounterID = "Queue:pfdhcplistener:api:process_dhcpv4"
)

// A task ID that outlived its data hash (the queue backlog exceeded the task
// TTL) must be reported as such and counted, the way the Perl consumer does in
// pf::pfqueue::consumer::redis. The expired counter used to be queued on an
// already-executed pipeline, so it never reached Redis at all, and it counted
// down instead of up.
func TestProcessNextQueueItemExpiredTask(t *testing.T) {
	s := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: s.Addr()})
	defer rdb.Close()

	ctx := context.Background()
	c := &Consumer{name: "test", redis: rdb}

	// What the producer left behind: the pending counter it bumped at
	// submission, and the task ID on the queue. The data hash is gone.
	if err := rdb.HSet(ctx, PFQUEUE_COUNTER, testCounterID, 1).Err(); err != nil {
		t.Fatalf("seeding the task counter: %s", err)
	}
	if err := rdb.LPush(ctx, testQueue, testTaskID).Err(); err != nil {
		t.Fatalf("seeding the queue: %s", err)
	}

	err := c.ProcessNextQueueItem(ctx, []string{testQueue})
	if !errors.Is(err, ErrTaskExpired) {
		t.Fatalf("expected ErrTaskExpired, got %v", err)
	}
	if !strings.Contains(err.Error(), testTaskID) {
		t.Errorf("the error should name the task that was dropped, got %q", err.Error())
	}

	if got := rdb.HGet(ctx, PFQUEUE_EXPIRED_COUNTER, testCounterID).Val(); got != "1" {
		t.Errorf("expired counter: got %q, want \"1\" (it must reach Redis, and count up)", got)
	}
	if got := rdb.HGet(ctx, PFQUEUE_COUNTER, testCounterID).Val(); got != "0" {
		t.Errorf("pending counter: got %q, want \"0\" (an expired task still leaves the queue)", got)
	}
}

// An empty queue is not an error condition: the caller distinguishes it from a
// real failure through redis.Nil.
func TestProcessNextQueueItemEmptyQueue(t *testing.T) {
	s := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: s.Addr()})
	defer rdb.Close()

	c := &Consumer{name: "test", redis: rdb}

	err := c.ProcessNextQueueItem(context.Background(), []string{testQueue})
	if !errors.Is(err, redis.Nil) {
		t.Fatalf("expected redis.Nil on an empty queue, got %v", err)
	}
	if errors.Is(err, ErrTaskExpired) {
		t.Error("an empty queue must not be reported as an expired task")
	}
}
