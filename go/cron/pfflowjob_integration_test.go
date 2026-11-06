//go:build integration

// Integration tests for the pfflow consumer against a throwaway Kafka broker
// (the confluentinc/cp-kafka image the PacketFence kafka container is built
// from). They need a working docker CLI and are excluded from the default
// build:
//
//	cd go/cron && ../../addons/dev-helpers/pf-go-test.sh -tags integration -run TestPfFlowKafka -v -timeout 15m .
package maint

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"testing"
	"time"

	"github.com/segmentio/kafka-go"
)

const integrationKafkaImage = "confluentinc/cp-kafka:7.5.2"

type kafkaContainer struct {
	name   string
	broker string
	env    []string
}

var containerSeq int

func freePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}

	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

// newKafkaContainer reserves a name and a port; the broker is only started by
// start(), so a test can run the consumer while Kafka is still down. env adds
// broker settings (KAFKA_*=value) to the defaults.
func newKafkaContainer(t *testing.T, env ...string) *kafkaContainer {
	t.Helper()
	if _, err := exec.LookPath("docker"); err != nil {
		t.Skip("docker is not available")
	}

	k := &kafkaContainer{
		name:   fmt.Sprintf("pfflow-it-kafka-%d-%d", os.Getpid(), containerSeq),
		broker: fmt.Sprintf("127.0.0.1:%d", freePort(t)),
		env:    env,
	}
	containerSeq++

	t.Cleanup(func() { exec.Command("docker", "rm", "-f", k.name).Run() })
	return k
}

// start runs a single node KRaft broker with Kafka's defaults otherwise
// (topic auto-creation on, default group initial rebalance delay), as in
// conf/kafka.conf.
func (k *kafkaContainer) start(t *testing.T) {
	t.Helper()
	_, port, _ := net.SplitHostPort(k.broker)
	args := []string{"run", "-d", "--rm", "--name", k.name}
	for _, e := range k.env {
		args = append(args, "-e", e)
	}

	out, err := exec.Command(
		"docker", append(args,
			"-p", k.broker+":9092",
			"-e", "CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk",
			"-e", "KAFKA_NODE_ID=1",
			"-e", "KAFKA_PROCESS_ROLES=broker,controller",
			"-e", "KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093",
			"-e", "KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER",
			"-e", "KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT",
			"-e", "KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093",
			"-e", "KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://127.0.0.1:"+port,
			"-e", "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT",
			"-e", "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1",
			integrationKafkaImage,
		)...).CombinedOutput()
	if err != nil {
		t.Fatalf("docker run: %v: %s", err, out)
	}
}

func (k *kafkaContainer) job(topic, group string) *PfFlowJob {
	return &PfFlowJob{
		Brokers:   []string{k.broker},
		ReadTopic: topic,
		GroupID:   group,
	}
}

// produce writes a flow tagged with seq every second until ctx is done,
// letting the broker auto-create the topic the way a flow exporter does.
func (k *kafkaContainer) produce(ctx context.Context, t *testing.T, topic string, seq uint32) {
	w := &kafka.Writer{
		Addr:                   kafka.TCP(k.broker),
		Topic:                  topic,
		AllowAutoTopicCreation: true,
		BatchTimeout:           10 * time.Millisecond,
	}

	value, _ := json.Marshal(&PfFlows{Header: PfFlowHeader{FlowSeq: seq}})
	go func() {
		defer w.Close()
		for ctx.Err() == nil {
			wctx, cancel := context.WithTimeout(ctx, 10*time.Second)
			if err := w.WriteMessages(wctx, kafka.Message{Value: value}); err != nil && ctx.Err() == nil {
				t.Logf("produce to %s: %v", topic, err)
			}

			cancel()
			select {
			case <-ctx.Done():
			case <-time.After(time.Second):
			}
		}
	}()
}

// writeFlows writes count flows tagged with seq, retrying while the broker or
// the topic is not ready yet (the writer auto-creates the topic).
func (k *kafkaContainer) writeFlows(t *testing.T, topic string, seq uint32, count int) {
	t.Helper()
	w := &kafka.Writer{
		Addr:                   kafka.TCP(k.broker),
		Topic:                  topic,
		AllowAutoTopicCreation: true,
		BatchTimeout:           10 * time.Millisecond,
	}
	defer w.Close()

	value, _ := json.Marshal(&PfFlows{Header: PfFlowHeader{FlowSeq: seq}})
	for i := 0; i < count; i++ {
		var err error
		for attempt := 0; attempt < 10; attempt++ {
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			err = w.WriteMessages(ctx, kafka.Message{Value: value})
			cancel()
			if err == nil {
				break
			}

			time.Sleep(time.Second)
		}

		if err != nil {
			t.Fatalf("produce to %s: %v", topic, err)
		}
	}
}

// waitForFlow waits for a flow tagged with seq on ChanPfFlow; flows of other
// scenarios (their Run() goroutines keep consuming) are skipped.
func waitForFlow(t *testing.T, seq uint32, timeout time.Duration) {
	t.Helper()
	deadline := time.After(timeout)
	for {
		select {
		case flows := <-ChanPfFlow:
			for _, f := range flows {
				if f.Header.FlowSeq == seq {
					return
				}
			}
		case <-deadline:
			t.Fatalf("no flow with seq %d consumed within %v", seq, timeout)
		}
	}
}

// stableGroup polls until the consumer group has settled with at least one
// member and returns its description, or false after timeout.
func stableGroup(client *kafka.Client, group string, timeout time.Duration) (kafka.DescribeGroupsResponseGroup, bool) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		resp, err := client.DescribeGroups(ctx, &kafka.DescribeGroupsRequest{GroupIDs: []string{group}})
		cancel()
		if err == nil {
			for _, g := range resp.Groups {
				if g.GroupID == group && g.Error == nil && g.GroupState == "Stable" && len(g.Members) > 0 {
					return g, true
				}
			}
		}

		time.Sleep(time.Second)
	}

	return kafka.DescribeGroupsResponseGroup{}, false
}

func waitForStableGroup(t *testing.T, client *kafka.Client, group string, timeout time.Duration) kafka.DescribeGroupsResponseGroup {
	t.Helper()
	g, ok := stableGroup(client, group, timeout)
	if !ok {
		t.Fatalf("consumer group %s not stable within %v", group, timeout)
	}

	return g
}

// ownsPartition reports whether a member of the group owns a partition of
// topic.
func ownsPartition(g kafka.DescribeGroupsResponseGroup, topic string) bool {
	for _, m := range g.Members {
		for _, t := range m.MemberAssignments.Topics {
			if t.Topic == topic && len(t.Partitions) > 0 {
				return true
			}
		}
	}

	return false
}

// readerJoinsWithPartition holds the flow exporter back, as in INV-948 where
// no flow is exported while PacketFence restarts, and checks that the first
// assignment the group settles on gives pfflow a partition. On a broker that
// auto-creates topics pfflow's own topic wait creates the topic, then the
// reader joins. Without the topic wait the reader joins first and gets an
// empty assignment, which fails the test even though the watchdog would later
// repair it: the guard must hold on its own.
func readerJoinsWithPartition(t *testing.T, j *PfFlowJob, timeout time.Duration) {
	t.Helper()
	g := waitForStableGroup(t, j.kafkaClient(), j.GroupID, timeout)
	if !ownsPartition(g, j.ReadTopic) {
		t.Fatalf("reader joined %s with no partition of %s assigned: %+v", j.GroupID, j.ReadTopic, g.Members)
	}
}

// giveReaderTimeToJoin is readerJoinsWithPartition for a broker that does not
// auto-create topics: while the topic is missing the reader must not join at
// all, so the group stays empty for the whole timeout.
func giveReaderTimeToJoin(t *testing.T, j *PfFlowJob, timeout time.Duration) {
	t.Helper()
	if g, ok := stableGroup(j.kafkaClient(), j.GroupID, timeout); ok {
		t.Fatalf("reader joined %s before the topic existed (assignment empty: %v)", j.GroupID, !ownsPartition(g, j.ReadTopic))
	}

	t.Logf("reader did not join %s within %v (waiting for the topic)", j.GroupID, timeout)
}

func TestPfFlowKafka(t *testing.T) {
	k := newKafkaContainer(t)

	// The scenarios share one broker and run in order: the first one needs
	// Kafka to be down when pfflow starts.
	t.Run("kafka down at start, topic missing", func(t *testing.T) {
		// INV-948: pfcron starts before Kafka and pfflows_events does not
		// exist. Before the fix the reader joined the group before the topic
		// existed and never got a partition.
		const seq = 1
		j := k.job("pfflows_it_down", "network_group_it_down")
		go j.Run()

		// Let the first waitForTopic attempts fail to dial.
		time.Sleep(5 * time.Second)
		k.start(t)
		readerJoinsWithPartition(t, j, 90*time.Second)

		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		k.produce(ctx, t, j.ReadTopic, seq)
		waitForFlow(t, seq, 4*time.Minute)

		g := waitForStableGroup(t, j.kafkaClient(), j.GroupID, time.Minute)
		if !ownsPartition(g, j.ReadTopic) {
			t.Fatalf("group %s has no partition of %s assigned: %+v", j.GroupID, j.ReadTopic, g.Members)
		}
	})

	t.Run("kafka up, topic missing", func(t *testing.T) {
		const seq = 2
		j := k.job("pfflows_it_up", "network_group_it_up")
		go j.Run()

		// pfflow must create the topic in waitForTopic before joining.
		readerJoinsWithPartition(t, j, 30*time.Second)
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		k.produce(ctx, t, j.ReadTopic, seq)
		waitForFlow(t, seq, 2*time.Minute)
	})

	t.Run("stuck reader is detected and recovered", func(t *testing.T) {
		// Reproduce the pre-fix behaviour with a bare reader that joins the
		// group while the topic does not exist, check that the watchdog's
		// DescribeGroups check flags it on a real broker, then recover the
		// way Run() does: close it, wait for the topic, create a new reader.
		j := k.job("pfflows_it_stuck", "network_group_it_stuck")
		ctx := context.Background()
		dialer := j.kafkaDialer()
		client := j.kafkaClient()

		stuck := j.newReader(ctx, dialer)
		defer stuck.Close()
		readCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
		_, err := stuck.ReadMessage(readCtx)
		cancel()
		if err == nil {
			t.Fatal("reader joined before the topic existed and still read a message")
		}

		// The reader's join auto-created the topic, after the assignment.
		wctx, cancel := context.WithTimeout(ctx, 30*time.Second)
		err = WaitForTopic(dialer, wctx, j.Brokers[0], j.ReadTopic, nil)
		cancel()
		if err != nil {
			t.Fatalf("topic %s was not auto-created by the reader's join: %v", j.ReadTopic, err)
		}

		pctx, stopProducing := context.WithCancel(ctx)
		defer stopProducing()
		k.produce(pctx, t, j.ReadTopic, 3)

		readCtx, cancel = context.WithTimeout(ctx, 20*time.Second)
		_, err = stuck.ReadMessage(readCtx)
		cancel()
		if err == nil {
			t.Fatal("reader without assignment read a message; the INV-948 condition was not reproduced")
		}

		waitForStableGroup(t, client, j.GroupID, time.Minute)
		noAssignment, err := j.groupHasNoAssignment(ctx, client)
		if err != nil {
			t.Fatalf("groupHasNoAssignment: %v", err)
		}

		if !noAssignment {
			t.Fatal("groupHasNoAssignment did not flag the reader stuck without a partition")
		}

		if err := stuck.Close(); err != nil {
			t.Logf("close stuck reader: %v", err)
		}

		j.waitForTopic(ctx, dialer)
		r := j.newReader(ctx, dialer)
		defer r.Close()
		readCtx, cancel = context.WithTimeout(ctx, time.Minute)
		_, err = r.ReadMessage(readCtx)
		cancel()
		if err != nil {
			t.Fatalf("recreated reader: %v", err)
		}

		noAssignment, err = j.groupHasNoAssignment(ctx, client)
		if err != nil {
			t.Fatalf("groupHasNoAssignment: %v", err)
		}

		if noAssignment {
			t.Fatal("groupHasNoAssignment flagged a reader that owns the partition")
		}
	})

	t.Run("group_id shared with a consumer of another topic", func(t *testing.T) {
		// Another consumer of another topic in the same group: the group is
		// stable with assignments on both topics, and the watchdog must not
		// take pfflow for stuck.
		const seq = 5
		group := "network_group_it_shared"
		other := "pfflows_it_shared_other"
		j := k.job("pfflows_it_shared", group)
		client := j.kafkaClient()

		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		k.produce(ctx, t, other, 0)
		k.produce(ctx, t, j.ReadTopic, seq)
		wctx, wcancel := context.WithTimeout(ctx, time.Minute)
		err := WaitForTopic(j.kafkaDialer(), wctx, k.broker, other, nil)
		wcancel()
		if err != nil {
			t.Fatalf("topic %s: %v", other, err)
		}

		otherReader := kafka.NewReader(kafka.ReaderConfig{Brokers: j.Brokers, Topic: other, GroupID: group})
		defer otherReader.Close()
		go func() {
			for ctx.Err() == nil {
				otherReader.ReadMessage(ctx)
			}
		}()

		go j.run(ctx)
		waitForFlow(t, seq, 2*time.Minute)

		deadline := time.Now().Add(time.Minute)
		var g kafka.DescribeGroupsResponseGroup
		for {
			g = waitForStableGroup(t, client, group, time.Minute)
			if len(g.Members) == 2 && ownsPartition(g, j.ReadTopic) && ownsPartition(g, other) {
				break
			}

			if time.Now().After(deadline) {
				t.Fatalf("group %s did not settle with both consumers: %+v", group, g.Members)
			}

			time.Sleep(time.Second)
		}

		stuck, err := j.groupHasNoAssignment(ctx, client)
		if err != nil {
			t.Fatalf("groupHasNoAssignment: %v", err)
		}

		if stuck {
			t.Fatalf("groupHasNoAssignment flagged pfflow stuck in a group shared with another topic: %+v", g.Members)
		}
	})

	t.Run("shutdown does not commit a flow it did not hand over", func(t *testing.T) {
		// With the aggregator channel full, pfflow fetches the flow but
		// cannot hand it over; shutting down then must leave it uncommitted
		// so the next consumer reads it again.
		j := k.job("pfflows_it_undelivered", "network_group_it_undelivered")
		client := j.kafkaClient()

		k.writeFlows(t, j.ReadTopic, 6, 1)
		qctx, qcancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer qcancel()
		listed, err := client.ListOffsets(qctx, &kafka.ListOffsetsRequest{
			Topics: map[string][]kafka.OffsetRequest{j.ReadTopic: {kafka.LastOffsetOf(0)}},
		})
		if err != nil || len(listed.Topics[j.ReadTopic]) != 1 || listed.Topics[j.ReadTopic][0].LastOffset != 1 {
			t.Fatalf("expected exactly one flow on %s: %+v, %v", j.ReadTopic, listed, err)
		}

		filler := []*PfFlows{{Header: PfFlowHeader{FlowSeq: 0}}}
		for len(ChanPfFlow) < cap(ChanPfFlow) {
			ChanPfFlow <- filler
		}

		defer func() {
			for len(ChanPfFlow) > 0 {
				<-ChanPfFlow
			}
		}()

		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		done := make(chan struct{})
		go func() {
			j.run(ctx)
			close(done)
		}()

		// Joined and fetching: it owns the partition and is blocked on the
		// full channel with the first flow.
		deadline := time.Now().Add(time.Minute)
		for {
			g, ok := stableGroup(client, j.GroupID, 10*time.Second)
			if ok && ownsPartition(g, j.ReadTopic) {
				break
			}

			if time.Now().After(deadline) {
				t.Fatalf("pfflow did not get the partition of %s", j.ReadTopic)
			}
		}

		time.Sleep(5 * time.Second)
		cancel()
		select {
		case <-done:
		case <-time.After(10 * time.Second):
			t.Fatal("run() did not return within 10s of shutdown")
		}

		qctx, qcancel = context.WithTimeout(context.Background(), 10*time.Second)
		defer qcancel()
		fetched, err := client.OffsetFetch(qctx, &kafka.OffsetFetchRequest{
			GroupID: j.GroupID,
			Topics:  map[string][]int{j.ReadTopic: {0}},
		})
		if err != nil {
			t.Fatalf("OffsetFetch: %v", err)
		}

		if got := fetched.Topics[j.ReadTopic][0].CommittedOffset; got > 0 {
			t.Fatalf("committed offset %d after shutdown, the flow that was never handed over is lost", got)
		}
	})

	t.Run("shutdown commits and leaves the group", func(t *testing.T) {
		// On shutdown run() must return, commit what it read and leave the
		// group, so the next pfcron gets the partition right away instead of
		// after the session timeout of this member, without reading again.
		const seq, count = 4, 5
		j := k.job("pfflows_it_shutdown", "network_group_it_shutdown")
		client := j.kafkaClient()

		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		done := make(chan struct{})
		go func() {
			j.run(ctx)
			close(done)
		}()

		k.writeFlows(t, j.ReadTopic, seq, count)
		for i := 0; i < count; i++ {
			waitForFlow(t, seq, 2*time.Minute)
		}

		waitForStableGroup(t, client, j.GroupID, time.Minute)
		cancel()
		select {
		case <-done:
		case <-time.After(10 * time.Second):
			t.Fatal("run() did not return within 10s of shutdown")
		}

		// The member left: the group is empty at once, not after its
		// session timeout (30s).
		qctx, qcancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer qcancel()
		resp, err := client.DescribeGroups(qctx, &kafka.DescribeGroupsRequest{GroupIDs: []string{j.GroupID}})
		if err != nil {
			t.Fatalf("DescribeGroups: %v", err)
		}

		for _, g := range resp.Groups {
			if g.GroupID == j.GroupID && (g.GroupState != "Empty" || len(g.Members) != 0) {
				t.Fatalf("group %s still %s with %d member(s) after shutdown", j.GroupID, g.GroupState, len(g.Members))
			}
		}

		// Everything read was committed.
		fetched, err := client.OffsetFetch(qctx, &kafka.OffsetFetchRequest{
			GroupID: j.GroupID,
			Topics:  map[string][]int{j.ReadTopic: {0}},
		})
		if err != nil {
			t.Fatalf("OffsetFetch: %v", err)
		}

		if got := fetched.Topics[j.ReadTopic][0].CommittedOffset; got != count {
			t.Fatalf("committed offset %d after shutdown, want %d (all %d flows read)", got, count, count)
		}
	})
}

// createTopic creates topic with one partition, retrying while the broker
// starts.
func (k *kafkaContainer) createTopic(t *testing.T, topic string) {
	t.Helper()
	client := &kafka.Client{Addr: kafka.TCP(k.broker), Timeout: 10 * time.Second}
	var err error
	for attempt := 0; attempt < 60; attempt++ {
		var resp *kafka.CreateTopicsResponse
		resp, err = client.CreateTopics(context.Background(), &kafka.CreateTopicsRequest{
			Topics: []kafka.TopicConfig{{Topic: topic, NumPartitions: 1, ReplicationFactor: 1}},
		})
		if err == nil {
			err = resp.Errors[topic]
		}

		if err == nil || errors.Is(err, kafka.TopicAlreadyExists) {
			return
		}

		time.Sleep(time.Second)
	}

	t.Fatalf("create topic %s: %v", topic, err)
}

func TestPfFlowKafkaNoAutoCreate(t *testing.T) {
	// A broker that does not auto-create topics answers pfflow's topic
	// request with UnknownTopicOrPartition: pfflow must keep polling it
	// (without joining the group, and without backing off as if the broker
	// were down) and start consuming within seconds of the topic's creation.
	k := newKafkaContainer(t, "KAFKA_AUTO_CREATE_TOPICS_ENABLE=false")
	k.start(t)

	const seq = 101
	j := k.job("pfflows_it_noauto", "network_group_it_noauto")
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		j.run(ctx)
		close(done)
	}()

	t.Cleanup(func() {
		cancel()
		<-done
	})

	// Hold the topic back for many polls: each answer is
	// UnknownTopicOrPartition, which must not make the reader join.
	giveReaderTimeToJoin(t, j, 45*time.Second)
	k.createTopic(t, j.ReadTopic)
	created := time.Now()
	k.writeFlows(t, j.ReadTopic, seq, 1)
	waitForFlow(t, seq, 20*time.Second)
	t.Logf("flow consumed %v after the topic was created", time.Since(created).Round(100*time.Millisecond))
}
