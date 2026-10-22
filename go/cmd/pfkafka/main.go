package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"time"

	"github.com/segmentio/kafka-go"
	"github.com/segmentio/kafka-go/sasl"
	"github.com/segmentio/kafka-go/sasl/plain"
)

func main() {
	// to consume messages
	topic := "pfflows_events"
	user := ""
	pass := ""
	broker := "localhost:9095"
	flag.StringVar(&topic, "topic", topic, "topic")
	flag.StringVar(&broker, "broker", broker, "broker")
	flag.StringVar(&user, "user", user, "user")
	flag.StringVar(&pass, "password", pass, "password")
	flag.Parse()
	fmt.Fprintf(os.Stderr, "listening to %s on %s\n", topic, broker)
	var mechanism sasl.Mechanism
	if user != "" && pass != "" {
		mechanism = plain.Mechanism{
			Username: user,
			Password: pass,
		}
	}

	dialer := &kafka.Dialer{
		Timeout:       10 * time.Second,
		DualStack:     true,
		SASLMechanism: mechanism,
	}
	//      partition := 0
	r := kafka.NewReader(kafka.ReaderConfig{

		Brokers:  []string{broker},
		Topic:    topic,
		GroupID:  "consumer-group-id" + topic,
		MaxBytes: 10e6, // 10MB
		Dialer:   dialer,
	})

	defer func() {
		if err := r.Close(); err != nil {
			log.Fatal("failed to close reader:", err)
		}
	}()

	ctx := context.Background()
	for {
		m, err := r.ReadMessage(ctx)
		if err != nil {
			// The reader was closed or the context was cancelled: nothing left to do.
			if errors.Is(err, io.EOF) || errors.Is(err, context.Canceled) {
				fmt.Fprintf(os.Stderr, "reader stopped: %s\n", err)
				break
			}
			// Transient errors (leader election, coordinator move, metadata
			// refresh, broker reconnects) are expected: kafka-go recovers on
			// the next read, so log and keep going instead of exiting.
			fmt.Fprintf(os.Stderr, "Error: %s\n", err)
			time.Sleep(time.Second)
			continue
		}
		//fmt.Printf("message at offset-partition %d-%d: %s = %s\n", m.Offset, m.Partition, string(m.Key), string(m.Value))
		fmt.Printf("%s\n", string(m.Value))
	}

}
