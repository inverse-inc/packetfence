package main

import (
	"context"
	"flag"
	"fmt"
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

	for {
		m, err := r.ReadMessage(context.Background())
		if err != nil {
			fmt.Printf("Error: %s", err)
			break
		}
		//fmt.Printf("message at offset-partition %d-%d: %s = %s\n", m.Offset, m.Partition, string(m.Key), string(m.Value))
		fmt.Printf("%s\n", string(m.Value))
	}

}
