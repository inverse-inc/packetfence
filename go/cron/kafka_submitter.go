package maint

import (
	"context"
	"database/sql"
	"encoding/json"
	"net"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/segmentio/kafka-go"
	"github.com/segmentio/kafka-go/compress"
	"github.com/segmentio/kafka-go/sasl/plain"
)

var (
	aggregatorMu      sync.Mutex
	aggregatorStarted bool
	// The flow pipeline SetupKafka started, drained by DrainFlowPipeline.
	pipelineAggregator *Aggregator
	pipelineSubmitter  *KafkaSubmiter
)

type KafkaSubmiterOptions struct {
	SubmitChan   chan []*NetworkEvent
	Hosts        []string
	Topic        string
	UseTLS       bool
	Username     string
	Password     string
	FilterEvents bool
}

type KafkaSubmiter struct {
	batchSubmitChan chan []*NetworkEvent
	writer          *kafka.Writer
	stop            chan struct{}
	done            chan struct{}
	filterEvents    bool
}

func (o *KafkaSubmiterOptions) Transport() *kafka.Transport {
	transport := &kafka.Transport{
		Dial: (&net.Dialer{
			Timeout:   3 * time.Second,
			DualStack: true,
		}).DialContext,
	}

	if o.Username != "" && o.Password != "" {
		transport.SASL = plain.Mechanism{
			Username: o.Username,
			Password: o.Password,
		}
	}

	return transport
}

func NewKafkaSubmiter(o *KafkaSubmiterOptions) (*KafkaSubmiter, error) {

	return &KafkaSubmiter{
		batchSubmitChan: o.SubmitChan,
		stop:            make(chan struct{}),
		done:            make(chan struct{}),
		writer: &kafka.Writer{
			Addr:                   kafka.TCP(o.Hosts...),
			Topic:                  o.Topic,
			Balancer:               kafka.Murmur2Balancer{},
			MaxAttempts:            10,
			WriteBackoffMax:        time.Second * 1,
			WriteBackoffMin:        time.Millisecond * 100,
			BatchSize:              100,
			BatchBytes:             1048576,
			BatchTimeout:           time.Second * 1,
			ReadTimeout:            time.Second * 10,
			WriteTimeout:           time.Second * 10,
			RequiredAcks:           kafka.RequireNone,
			Async:                  false,
			Completion:             nil,
			Compression:            compress.None,
			Logger:                 nil,
			ErrorLogger:            nil,
			Transport:              o.Transport(),
			AllowAutoTopicCreation: true,
		},
		filterEvents: o.FilterEvents != false,
	}, nil
}

// Run sends the batches of batchSubmitChan until the channel is closed (or
// Stop is called and the channel is then closed), then closes the writer,
// which flushes what it still holds, and closes done.
func (s *KafkaSubmiter) Run() {
	defer close(s.done)
LOOP:
	for {
		select {
		case <-s.stop:
			break LOOP
		case events, ok := <-s.batchSubmitChan:
			if !ok {
				break LOOP
			}

			s.send(events)
		}
	}

	for events := range s.batchSubmitChan {
		s.send(events)
	}

	s.shutdown()
}

func (s *KafkaSubmiter) shutdown() {
	s.writer.Close()
}

func (s *KafkaSubmiter) send(events []*NetworkEvent) {
	var filteredEvents []*NetworkEvent
	if s.filterEvents {
		db, err := getDb()
		if err != nil {
			log.LogErrorf(context.Background(), "Failed to get database connection for filtering: %v", err)
		} else {
			filter, err := GetFilterFromNetworkEvents(db, events)
			if err != nil {
				log.LogErrorf(context.Background(), "Failed to get filter from network events: %v", err)
			} else {
				filteredEvents = filter.FilterEvents(events)
			}
		}

	} else {
		filteredEvents = events
	}

	ctx := context.Background()
	messages := make([]kafka.Message, 0, len(filteredEvents))
	for i := 0; i < len(filteredEvents); i++ {
		data, err := json.Marshal(filteredEvents[i])
		if err != nil {
			log.LogErrorf(ctx, "Failed to marshal network event: %v", err)
			continue
		}
		messages = append(messages, kafka.Message{Value: data})
	}

	if len(messages) == 0 {
		log.LogDebugf(ctx, "No messages to send to Kafka after filtering")
		return
	}

	log.LogInfof(
		ctx,
		"Sending %d network events to kafka",
		len(messages),
	)

	// WriteMessages with error handling - kafka.Writer has built-in retry logic
	// with MaxAttempts (10), WriteBackoffMin (100ms), and WriteBackoffMax (1s)
	err := s.writer.WriteMessages(ctx, messages...)
	if err != nil {
		log.LogErrorf(
			ctx,
			"Failed to write %d messages to Kafka after retries: %v",
			len(messages),
			err,
		)
		// The kafka.Writer will automatically retry up to MaxAttempts times
		// with exponential backoff between WriteBackoffMin and WriteBackoffMax
		// If it still fails after all retries, the connection may be down
		// and the writer will attempt to reconnect on the next WriteMessages call
	} else {
		log.LogDebugf(ctx, "Successfully sent %d messages to Kafka", len(messages))
	}
}

func (s *KafkaSubmiter) Stop() {
	s.stop <- struct{}{}
}

func interfaceArrayToStringArray(a []interface{}) []string {
	array := make([]string, len(a))
	for i := range a {
		array[i] = a[i].(string)
	}

	return array
}

func SetupKafka(config map[string]interface{}) {
	aggregatorMu.Lock()
	defer aggregatorMu.Unlock()

	// Already started successfully, nothing to do
	if aggregatorStarted {
		return
	}

	ctx := context.Background()
	GlobalReportingEntity.UUID = config["uuid"].(string)
	batch_submit := int(config["submit_batch"].(float64))
	hosts := interfaceArrayToStringArray(config["kafka_brokers"].([]interface{}))
	aggregatorChan := make(chan []*NetworkEvent, batch_submit)
	options := KafkaSubmiterOptions{
		SubmitChan:   aggregatorChan,
		Hosts:        hosts,
		Topic:        config["write_topic"].(string),
		Username:     config["kafka_user"].(string),
		Password:     config["kafka_pass"].(string),
		FilterEvents: sharedutils.ISENABLED[config["filter_events"].(string)],
	}

	// Retry database connection until it succeeds
	var db *sql.DB
	var err error
	for {
		db, err = getDb()
		if err == nil {
			break
		}
		log.LogErrorf(ctx, "SetupKafka: failed to connect to database, retrying in 5s: %s", err.Error())
		time.Sleep(5 * time.Second)
	}

	go UpdatePolicyMap(ctx, db)
	submitter, err := NewKafkaSubmiter(&options)
	if err != nil {
		log.LogErrorf(ctx, "SetupKafka: failed to create Kafka submitter: %s", err.Error())
		return
	}

	go submitter.Run()
	pipelineSubmitter = submitter

	aggregator := NewAggregator(
		&AggregatorOptions{
			NetworkEventChan: aggregatorChan,
			Timeout:          time.Minute,
			Heuristics:       sharedutils.ISENABLED[config["heuristics"].(string)],
			Db:               db,
		},
	)
	go aggregator.handleEvents()
	pipelineAggregator = aggregator

	// Mark as successfully started only after everything is set up
	aggregatorStarted = true
	log.LogInfof(ctx, "SetupKafka: aggregator and submitter started successfully")
}

// pipelineDrainTimeout bounds DrainFlowPipeline, within pfcron's default
// 90s stop timeout (TimeoutStopSec).
const pipelineDrainTimeout = 60 * time.Second

var drainOnce sync.Once

// DrainFlowPipeline processes every flow pfflow has handed over and not yet
// processed: the ones queued for the fingerprinting and the aggregator, the
// aggregator's open window and the network events waiting for the submitter.
// pfflow calls it on shutdown, after it stopped handing flows over and before
// its reader commits their offsets, so a flow is not committed and then lost.
// The pipeline cannot be used afterwards. It returns false if the pipeline did
// not drain within timeout; flows still in it are then lost. It does nothing
// when the pipeline was never started.
func DrainFlowPipeline(ctx context.Context, timeout time.Duration) bool {
	drained := true
	drainOnce.Do(func() {
		aggregatorMu.Lock()
		aggregator, submitter := pipelineAggregator, pipelineSubmitter
		aggregatorMu.Unlock()
		fingerprinting := pipelineFingerprinting()

		if aggregator == nil && submitter == nil && fingerprinting == nil {
			return
		}

		done := make(chan struct{})
		go func() {
			defer close(done)
			var wg sync.WaitGroup
			if fingerprinting != nil {
				wg.Add(1)
				go func() {
					defer wg.Done()
					close(fingerprintChan)
					fingerprinting.Stop()
				}()
			}

			if aggregator != nil {
				// The aggregator's flusher sends to the submitter: the
				// submitter's channel is closed only once it is done.
				aggregator.Stop()
			}

			if submitter != nil {
				close(submitter.batchSubmitChan)
				<-submitter.done
			}

			wg.Wait()
		}()

		log.LogInfof(ctx, "pfflow: processing the flows already read before stopping")
		select {
		case <-done:
			log.LogInfof(ctx, "pfflow: all flows read were processed")
		case <-time.After(timeout):
			drained = false
			log.LogWarnf(ctx, "pfflow: flows read were not all processed within %s, the remaining ones are lost", timeout)
		}
	})

	return drained
}
