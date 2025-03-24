package maint

import (
	"context"
	"encoding/json"
	"fmt"
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
	r := kafka.NewReader(kafka.ReaderConfig{

		Brokers:  j.Brokers,
		Topic:    j.ReadTopic,
		GroupID:  j.GroupID,
		MaxBytes: 10e6, // 10MB
		Dialer:   j.kafkaDialer(),
	})

	defer func() {
		if err := r.Close(); err != nil {
			log.Fatal("failed to close reader:", err)
		}
	}()

	for {
		m, err := r.ReadMessage(context.Background())
		if err != nil {
			fmt.Printf("Error : %s\n", err.Error())
			break
		}

		pfFlows := &PfFlows{}
		if err := json.Unmarshal(m.Value, pfFlows); err != nil {
			continue
		}

		ChanPfFlow <- []*PfFlows{pfFlows}
		if j.fingerprintChan != nil {
			j.fingerprintChan <- []*PfFlows{pfFlows}
		}
	}
}
