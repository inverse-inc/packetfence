package maint

import (
	"context"
	"encoding/json"
	"net"
	"sync"
	"time"

	"github.com/segmentio/kafka-go"
	"github.com/segmentio/kafka-go/compress"
	"github.com/segmentio/kafka-go/sasl/plain"
)

var aggregatorOnce sync.Once

type KafkaSubmiterOptions struct {
	SubmitChan   chan []*NetworkEvent
	Hosts        []string
	Topic        string
	UseTLS       bool
	Username     string
	Password     string
	FilterEvents int
}

type KafkaSubmiter struct {
	batchSubmitChan chan []*NetworkEvent
	writer          *kafka.Writer
	stop            chan struct{}
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
		filterEvents: o.FilterEvents != 0,
	}, nil
}

func (s *KafkaSubmiter) Run() {
LOOP:
	for {
		select {
		case <-s.stop:
			break LOOP
		case events := <-s.batchSubmitChan:
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
		} else {
			filter, err := GetFilterFromNetworkEvents(db, events)
			if err != nil {
			} else {
				filteredEvents = filter.FilterEvents(events)
			}
		}

	} else {
		filteredEvents = events
	}

	messages := make([]kafka.Message, 0, len(filteredEvents))
	for i := 0; i < len(filteredEvents); i++ {
		data, err := json.Marshal(events[i])
		if err != nil {
			//TODO log error
			continue
		}
		messages = append(messages, kafka.Message{Value: data})
	}

	s.writer.WriteMessages(context.Background(), messages...)
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
	aggregatorOnce.Do(func() {
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
			FilterEvents: int(config["filter_events"].(float64)),
		}

		db, err := getDb()
		if err != nil {
			panic(err.Error())
		}

		go UpdatePolicyMap(context.Background(), db)
		submitter, err := NewKafkaSubmiter(&options)
		if err != nil {
			panic(err.Error())
		}

		go submitter.Run()

		aggregator := NewAggregator(
			&AggregatorOptions{
				NetworkEventChan: aggregatorChan,
				Timeout:          time.Minute,
				Heuristics:       int(config["heuristics"].(float64)),
				Db:               db,
			},
		)
		go aggregator.handleEvents()
	})
}
