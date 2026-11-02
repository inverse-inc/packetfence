package maint

import (
	"context"
	"net"
	"testing"
	"time"

	"github.com/segmentio/kafka-go"
)

func TestKafkaSubmitter(t *testing.T) {
	jobsConfig := GetMaintenanceConfig(context.Background())
	SetupKafka(jobsConfig["pfflow"].(map[string]interface{}))
}

func TestIsStrandedOffset(t *testing.T) {
	cases := []struct {
		name            string
		committed, last int64
		brokerConfirmed bool
		want            bool
	}{
		{"no committed offset (-1) on a live partition", -1, 100, false, false},
		{"no committed offset (-1) on an empty partition", -1, 0, false, false},
		{"no committed offset (-1), broker confirmed", -1, 0, true, false},
		{"committed behind the log end", 50, 100, false, false},
		{"committed behind the log end, broker confirmed (kafka-go skips ahead itself)", 50, 100, true, false},
		{"committed equals the log end (caught up)", 100, 100, false, false},
		{"caught up on an empty partition", 0, 0, true, false},
		{"committed past the log end: topic recreated", 5_000_000, 110_000, false, true},
		{"committed past the log end, broker confirmed", 5_000_000, 110_000, true, true},
		{"negative log end must never rewind", 5_000_000, -1, false, false},
		{"negative log end must never rewind even when broker confirmed", 5_000_000, -1, true, false},
		{"log end 0 from a periodic/idle check: absent partition or empty topic, must not rewind", 5_000_000, 0, false, false},
		{"log end 0 after the broker answered OffsetOutOfRange: empty recreated topic, reset", 5_000_000, 0, true, true},
	}
	for _, c := range cases {
		if got := isStrandedOffset(c.committed, c.last, c.brokerConfirmed); got != c.want {
			t.Errorf("%s: isStrandedOffset(%d, %d, %v) = %v, want %v", c.name, c.committed, c.last, c.brokerConfirmed, got, c.want)
		}
	}
}

func TestNoPartitionAssigned(t *testing.T) {
	const topic = "pfflows_events"
	member := func(topics ...kafka.GroupMemberTopic) kafka.DescribeGroupsResponseMember {
		return kafka.DescribeGroupsResponseMember{
			MemberAssignments: kafka.DescribeGroupsResponseAssignments{Topics: topics},
		}
	}

	cases := []struct {
		name  string
		group kafka.DescribeGroupsResponseGroup
		want  bool
	}{
		{"stable, single member without assignment", kafka.DescribeGroupsResponseGroup{GroupState: "Stable", Members: []kafka.DescribeGroupsResponseMember{member()}}, true},
		{"stable, assigned an empty partition list", kafka.DescribeGroupsResponseGroup{GroupState: "Stable", Members: []kafka.DescribeGroupsResponseMember{member(kafka.GroupMemberTopic{Topic: topic})}}, true},
		{"stable, only another topic assigned", kafka.DescribeGroupsResponseGroup{GroupState: "Stable", Members: []kafka.DescribeGroupsResponseMember{member(kafka.GroupMemberTopic{Topic: "other", Partitions: []int{0}})}}, true},
		{"stable, partition assigned", kafka.DescribeGroupsResponseGroup{GroupState: "Stable", Members: []kafka.DescribeGroupsResponseMember{member(kafka.GroupMemberTopic{Topic: topic, Partitions: []int{0}})}}, false},
		{"stable, another member owns the partition", kafka.DescribeGroupsResponseGroup{GroupState: "Stable", Members: []kafka.DescribeGroupsResponseMember{member(), member(kafka.GroupMemberTopic{Topic: topic, Partitions: []int{0}})}}, false},
		{"stable, no member", kafka.DescribeGroupsResponseGroup{GroupState: "Stable"}, false},
		{"empty group", kafka.DescribeGroupsResponseGroup{GroupState: "Empty"}, false},
		{"rebalancing", kafka.DescribeGroupsResponseGroup{GroupState: "CompletingRebalance", Members: []kafka.DescribeGroupsResponseMember{member()}}, false},
	}

	for _, c := range cases {
		if got := noPartitionAssigned(c.group, topic); got != c.want {
			t.Errorf("%s: noPartitionAssigned() = %v, want %v", c.name, got, c.want)
		}
	}
}

func TestPfFlowRunStopsWhileWaitingForKafka(t *testing.T) {
	// Nothing listens on the port: run() keeps waiting for the broker and
	// must still return once ctx is done.
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}

	broker := l.Addr().String()
	l.Close()

	j := &PfFlowJob{Brokers: []string{broker}, ReadTopic: "pfflows_events", GroupID: "network_group"}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		j.run(ctx)
		close(done)
	}()

	time.Sleep(3 * time.Second)
	cancel()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("run() did not return after its context was cancelled")
	}
}

func TestWaitForTopicSilentBroker(t *testing.T) {
	// A broker that accepts the connection and never answers: WaitForTopic
	// must still return when its context expires.
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}

	defer l.Close()
	go func() {
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}

			defer c.Close()
		}
	}()

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	done := make(chan error, 1)
	go func() {
		done <- WaitForTopic(&kafka.Dialer{Timeout: 10 * time.Second}, ctx, l.Addr().String(), "pfflows_events")
	}()

	select {
	case err := <-done:
		if err == nil {
			t.Fatal("WaitForTopic found a topic on a broker that never answers")
		}
	case <-time.After(10 * time.Second):
		t.Fatal("WaitForTopic did not return after its context expired")
	}
}
