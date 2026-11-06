package maint

import (
	"context"
	"net"
	"net/netip"
	"sync"
	"testing"
	"time"
)

// drainTestFlows is one message with a single flow, enough for the
// aggregator to produce one network event.
func drainTestFlows() []*PfFlows {
	return []*PfFlows{
		{
			Header: PfFlowHeader{DomainID: 1, FlowSeq: 1},
			Flows: &[]PfFlow{
				{
					SrcMac:          "00:11:22:33:44:55",
					DstMac:          "00:11:22:33:44:56",
					SrcIp:           netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					DstIp:           netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					SrcPort:         80,
					DstPort:         1025,
					Proto:           6,
					BiFlow:          2,
					ConnectionCount: 2,
				},
			},
		},
	}
}

// newDrainTestAggregator returns a running aggregator reading its own channel
// (not ChanPfFlow) with a window that never ticks during the test.
func newDrainTestAggregator(t *testing.T) (*Aggregator, chan []*NetworkEvent) {
	t.Helper()
	db, err := getDb()
	if err != nil {
		t.Skipf("no database: %s", err)
	}

	networkEventChan := make(chan []*NetworkEvent, 10)
	a := NewAggregator(&AggregatorOptions{
		Timeout:          time.Hour,
		NetworkEventChan: networkEventChan,
		Db:               db,
	})
	a.PfFlowsChan = make(chan []*PfFlows, 10)
	go a.handleEvents()
	return a, networkEventChan
}

func TestAggregatorStopFlushesOpenWindow(t *testing.T) {
	a, networkEventChan := newDrainTestAggregator(t)
	// Still queued when Stop is called, or already in the open window:
	// either way it must come out as a network event before Stop returns.
	a.PfFlowsChan <- drainTestFlows()

	stopped := make(chan struct{})
	go func() {
		a.Stop()
		close(stopped)
	}()

	select {
	case <-stopped:
	case <-time.After(10 * time.Second):
		t.Fatal("Stop did not return")
	}

	select {
	case ne := <-networkEventChan:
		if len(ne) != 1 {
			t.Fatalf("got %d network events, want 1", len(ne))
		}
	default:
		t.Fatal("Stop returned without flushing the open window")
	}
}

func TestKafkaSubmitterStopsWhenChannelClosed(t *testing.T) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}

	broker := l.Addr().String()
	l.Close()

	submitChan := make(chan []*NetworkEvent, 1)
	s, err := NewKafkaSubmiter(&KafkaSubmiterOptions{SubmitChan: submitChan, Hosts: []string{broker}, Topic: "test"})
	if err != nil {
		t.Fatal(err)
	}

	go s.Run()
	close(submitChan)
	select {
	case <-s.done:
	case <-time.After(5 * time.Second):
		t.Fatal("Run did not return after its channel was closed")
	}
}

// withDrainPipeline installs aggregator as the pipeline DrainFlowPipeline
// drains, with a fresh drainOnce, and restores the previous state afterwards.
func withDrainPipeline(t *testing.T, aggregator *Aggregator) {
	t.Helper()
	aggregatorMu.Lock()
	prevAggregator, prevSubmitter := pipelineAggregator, pipelineSubmitter
	pipelineAggregator, pipelineSubmitter = aggregator, nil
	aggregatorMu.Unlock()
	prevFingerprinting := fingerprintingJob
	fingerprintingJob = nil
	drainOnce = sync.Once{}
	t.Cleanup(func() {
		aggregatorMu.Lock()
		pipelineAggregator, pipelineSubmitter = prevAggregator, prevSubmitter
		aggregatorMu.Unlock()
		fingerprintingJob = prevFingerprinting
		drainOnce = sync.Once{}
	})
}

func TestDrainFlowPipeline(t *testing.T) {
	a, networkEventChan := newDrainTestAggregator(t)
	withDrainPipeline(t, a)
	a.PfFlowsChan <- drainTestFlows()

	if !DrainFlowPipeline(context.Background(), 10*time.Second) {
		t.Fatal("DrainFlowPipeline timed out")
	}

	select {
	case <-networkEventChan:
	default:
		t.Fatal("DrainFlowPipeline returned before the queued flows were processed")
	}

	// Only once: a second call must not stop the aggregator again.
	if !DrainFlowPipeline(context.Background(), time.Second) {
		t.Fatal("second DrainFlowPipeline call did not return at once")
	}
}

func TestDrainFlowPipelineTimeout(t *testing.T) {
	// handleEvents never runs: Stop blocks and the drain must give up.
	a := NewAggregator(&AggregatorOptions{Timeout: time.Hour})
	withDrainPipeline(t, a)

	start := time.Now()
	if DrainFlowPipeline(context.Background(), time.Second) {
		t.Fatal("DrainFlowPipeline reported success with a stuck aggregator")
	}

	if d := time.Since(start); d > 3*time.Second {
		t.Fatalf("DrainFlowPipeline took %s, want about 1s", d)
	}
}

func TestStartSchedule(t *testing.T) {
	var s startSchedule
	now := time.Date(2026, 11, 6, 12, 0, 0, 0, time.UTC)
	if got := s.Next(now); !got.Equal(now) {
		t.Fatalf("first Next = %s, want %s (start at once)", got, now)
	}

	// The fire was skipped (not the processing node, say): retry.
	if got := s.Next(now); !got.Equal(now.Add(startRetryInterval)) {
		t.Fatalf("Next before the job started = %s, want %s", got, now.Add(startRetryInterval))
	}

	s.markStarted()

	if got := s.Next(now); !got.IsZero() {
		t.Fatalf("Next once started = %s, want the zero time", got)
	}
}

func TestPfFlowRunWithoutBrokers(t *testing.T) {
	pfflowSchedule.started.Store(false)
	t.Cleanup(func() { pfflowSchedule.started.Store(false) })

	done := make(chan struct{})
	go func() {
		(&PfFlowJob{ReadTopic: "pfflows_events", GroupID: "network_group"}).Run()
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("Run with an empty kafka_brokers did not return")
	}
}
