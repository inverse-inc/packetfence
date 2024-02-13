package maint

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/segmentio/kafka-go"
)

var ChanPfFlow chan []*PfFlows = make(chan []*PfFlows, 1000)

type PfFlowJob struct {
	Task
	ReadTopic string
	Brokers   []string
	GroupID   string
	UUID      string
}

func NewPfFlowJob(config map[string]interface{}) JobSetupConfig {
	hosts := interfaceArrayToStringArray(config["kafka_brokers"].([]interface{}))
	SetupKafka(config)
	return &PfFlowJob{
		Task:      SetupTask(config),
		Brokers:   hosts,
		GroupID:   config["group_id"].(string),
		ReadTopic: config["read_topic"].(string),
		UUID:      config["uuid"].(string),
	}
}

func (j *PfFlowJob) Run() {
	r := kafka.NewReader(kafka.ReaderConfig{

		Brokers:  j.Brokers,
		Topic:    j.ReadTopic,
		GroupID:  j.GroupID,
		MaxBytes: 10e6, // 10MB
	})

	defer func() {
		if err := r.Close(); err != nil {
			log.Fatal("failed to close reader:", err)
		}
	}()
	fmt.Println("Helloe")
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
	}
}
