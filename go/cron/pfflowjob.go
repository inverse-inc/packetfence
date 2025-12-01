package maint

import (
	"context"
	"encoding/json"
	"log"
	"strconv"
	"time"

	"github.com/segmentio/kafka-go"
	"github.com/segmentio/kafka-go/sasl/plain"
)

var ChanPfFlow chan []*PfFlows = make(chan []*PfFlows, 1000)

type PfFlowJob struct {
	Task
	ReadTopic       string
	Brokers         []string
	GroupID         string
	UUID            string
	UserName        string
	Password        string
	FilterEvents    int
	fingerprintChan chan []*PfFlows
}

func defaultFromConfig[T any](config map[string]interface{}, name string, defaultVal T) T {
	i := config[name]
	if i == nil {
		return defaultVal
	}

	if v, ok := i.(T); ok {
		return v
	}

	return defaultVal
}

func defaultIntConfig(config map[string]interface{}, name string, defaultVal int) int {
	i := config[name]
	if i == nil {
		return defaultVal
	}

	switch v := i.(type) {
	case string:
		val, err := strconv.ParseInt(v, 10, 64)
		if err != nil {
			return defaultVal
		}

		return int(val)
	case int64:
		return int(v)
	case float64:
		return int(v)
	default:
		return defaultVal
	}
}

func NewPfFlowJob(config map[string]interface{}) JobSetupConfig {
	hosts := interfaceArrayToStringArray(config["kafka_brokers"].([]interface{}))
	SetupKafka(config)

	fingerbankChan := SetupFingerPrintingJob(config)
	return &PfFlowJob{
		Task:            SetupTask(config),
		Brokers:         hosts,
		GroupID:         config["group_id"].(string),
		ReadTopic:       config["read_topic"].(string),
		UUID:            config["uuid"].(string),
		UserName:        config["kafka_user"].(string),
		Password:        config["kafka_pass"].(string),
		fingerprintChan: fingerbankChan,
	}
}

func (j *PfFlowJob) kafkaDialer() *kafka.Dialer {
	dialer := kafka.Dialer{
		DualStack: true,
		Timeout:   10 * time.Second,
	}

	if j.UserName != "" && j.Password != "" {
		dialer.SASLMechanism = plain.Mechanism{
			Username: j.UserName,
			Password: j.Password,
		}
	}

	return &dialer
}

func (j *PfFlowJob) Run() {
	var r *kafka.Reader
	maxReconnectDelay := 60 * time.Second
	reconnectDelay := 1 * time.Second
	consecutiveErrors := 0

	defer func() {
		if r != nil {
			if err := r.Close(); err != nil {
				log.Printf("failed to close reader: %v", err)
			}
		}
	}()

	for {
		// Create or recreate the reader
		if r == nil {
			log.Printf("Connecting to Kafka brokers: %v, topic: %s", j.Brokers, j.ReadTopic)
			r = kafka.NewReader(kafka.ReaderConfig{
				Brokers:  j.Brokers,
				Topic:    j.ReadTopic,
				GroupID:  j.GroupID,
				MaxBytes: 10e6, // 10MB
				Dialer:   j.kafkaDialer(),
			})
		}

		// Use a timeout context to avoid blocking forever if Kafka is unresponsive
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		m, err := r.ReadMessage(ctx)
		cancel()
		if err != nil {
			// Check if it's just a timeout (no messages available) vs a real error
			if err == context.DeadlineExceeded {
				// Timeout waiting for messages is normal, just retry without reconnecting
				continue
			}

			consecutiveErrors++
			log.Printf("Error reading from Kafka (attempt %d): %s", consecutiveErrors, err.Error())

			// Close the current reader on error
			if closeErr := r.Close(); closeErr != nil {
				log.Printf("Error closing reader: %v", closeErr)
			}
			r = nil

			// Exponential backoff with max delay
			if reconnectDelay < maxReconnectDelay {
				reconnectDelay = reconnectDelay * 2
				if reconnectDelay > maxReconnectDelay {
					reconnectDelay = maxReconnectDelay
				}
			}

			log.Printf("Reconnecting to Kafka in %v...", reconnectDelay)
			time.Sleep(reconnectDelay)
			continue
		}

		// Reset error counter and delay on successful read
		if consecutiveErrors > 0 {
			log.Printf("Successfully reconnected to Kafka after %d errors", consecutiveErrors)
			consecutiveErrors = 0
			reconnectDelay = 1 * time.Second
		}

		pfFlows := &PfFlows{}
		if err := json.Unmarshal(m.Value, pfFlows); err != nil {
			log.Printf("Error unmarshaling message: %v", err)
			continue
		}

		ChanPfFlow <- []*PfFlows{pfFlows}
		if j.fingerprintChan != nil {
			// Send the flows to the fingerprint channel
			j.fingerprintChan <- []*PfFlows{pfFlows}
		}
	}
}
