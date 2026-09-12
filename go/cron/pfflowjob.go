package maint

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/robfig/cron/v3"
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
	schedule        OnceSchedule
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
		schedule:        OnceSchedule{},
	}
}

type OnceSchedule struct {
	ran atomic.Bool
}

func (o *OnceSchedule) Next(n time.Time) time.Time {
	if o.ran.CompareAndSwap(false, true) {
		return n
	}

	return time.Time{}
}

func (j *PfFlowJob) Schedule() cron.Schedule {
	return &j.schedule
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

// kafkaClient returns a low level client used for consumer group offset
// inspection and repair.
func (j *PfFlowJob) kafkaClient() *kafka.Client {
	transport := &kafka.Transport{
		Dial: (&net.Dialer{
			Timeout:   10 * time.Second,
			DualStack: true,
		}).DialContext,
	}

	if j.UserName != "" && j.Password != "" {
		transport.SASL = plain.Mechanism{
			Username: j.UserName,
			Password: j.Password,
		}
	}

	return &kafka.Client{
		Addr:      kafka.TCP(j.Brokers...),
		Timeout:   10 * time.Second,
		Transport: transport,
	}
}

// readTimeout bounds one ReadMessage call. When it expires without a message
// the consumer group offset is checked against the partition log end.
const readTimeout = 60 * time.Second

func (j *PfFlowJob) newReader(ctx context.Context, dialer *kafka.Dialer) *kafka.Reader {
	return kafka.NewReader(kafka.ReaderConfig{
		Brokers:  j.Brokers,
		Topic:    j.ReadTopic,
		GroupID:  j.GroupID,
		MaxBytes: 10e6, // 10MB
		Dialer:   dialer,
		// Commit offsets asynchronously once a second. With the default (0)
		// kafka-go commits synchronously after every ReadMessage, which costs
		// one broker round trip per flow and caps the consumer well below the
		// flow rate of a large deployment.
		CommitInterval: time.Second,
		Logger: kafka.LoggerFunc(func(msg string, args ...interface{}) {
			log.LogDebugf(ctx, "kafka reader: "+msg, args...)
		}),
		// Without an ErrorLogger kafka-go silently retries forever when the
		// group offset is past the end of the partition.
		ErrorLogger: kafka.LoggerFunc(func(msg string, args ...interface{}) {
			log.LogErrorf(ctx, "kafka reader: "+msg, args...)
		}),
		// Return OffsetOutOfRange from ReadMessage instead of retrying the
		// fetch forever, so Run() can repair a stranded group offset as soon
		// as the broker reports it rather than after readTimeout of silence.
		OffsetOutOfRangeError: true,
	})
}

// strandedCheckInterval bounds how long a stranded partition can go unnoticed
// while other partitions of the topic keep delivering messages (the idle-read
// path only fires when the whole topic is silent).
const strandedCheckInterval = 5 * time.Minute

// repairCooldown is how long Run() waits before retrying a failed offset
// reset, so a reset that cannot succeed (see commitGroupOffsets) does not
// close and rebuild the reader every readTimeout.
const repairCooldown = 5 * time.Minute

// isStrandedOffset reports whether a committed group offset lies past the end
// of its partition, which happens when the topic was deleted and recreated
// behind the consumer: kafka-go then fetches from an offset that does not
// exist and never advances. lastOffset <= 0 means the log end is unknown or
// the partition is empty and is never treated as stranded (an empty answer
// from ListOffsets must not rewind a healthy group to 0); committed < 0 means
// the group has no offset for the partition.
func isStrandedOffset(committed, lastOffset int64) bool {
	return lastOffset > 0 && committed > lastOffset
}

// WaitForTopic polls the broker until the topic appears or the context times out
func WaitForTopic(dialer *kafka.Dialer, ctx context.Context, brokerAddr string, topic string) error {
	// 1. Establish a connection to the broker
	// We dial inside the function, but in a real app you might reuse an existing connection.
	conn, err := dialer.Dial("tcp", brokerAddr)
	if err != nil {
		return fmt.Errorf("failed to dial broker: %w", err)
	}
	defer conn.Close()

	// 2. Create a ticker for the polling interval (e.g., check every 1 second)
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return errors.New("timed out waiting for topic creation")
		case <-ticker.C:
			// 3. Fetch list of all partitions (metadata)
			partitions, err := conn.ReadPartitions()
			if err != nil {
				// Optional: You might want to log this error, but generally
				// we keep retrying in case the broker is temporarily restarting.
				log.LogWarnf(ctx, "Failed to read partitions, retrying: %v", err)
				continue
			}

			// 4. Check if our topic exists in the partition list
			for _, p := range partitions {
				if p.Topic == topic {
					return nil // Topic found!
				}
			}

			// If we get here, the topic was not found in this cycle.
			// The loop continues on the next tick.
		}
	}
}

// staleGroupOffsets returns, for every partition of the read topic whose
// committed group offset is past the partition's last offset, the commit that
// moves it back to the log end. This happens when the topic is deleted and
// recreated behind the consumer: the group keeps its old (now unreachable)
// offset and kafka-go waits forever for the log to catch up with it.
func (j *PfFlowJob) staleGroupOffsets(ctx context.Context, client *kafka.Client) ([]kafka.OffsetCommit, error) {
	meta, err := client.Metadata(ctx, &kafka.MetadataRequest{Topics: []string{j.ReadTopic}})
	if err != nil {
		return nil, err
	}

	partitions := []int{}
	for _, t := range meta.Topics {
		if t.Name != j.ReadTopic {
			continue
		}

		if t.Error != nil {
			return nil, t.Error
		}

		for _, p := range t.Partitions {
			partitions = append(partitions, p.ID)
		}
	}

	if len(partitions) == 0 {
		return nil, nil
	}

	// Committed offsets first, log ends second. Both only grow, so a commit
	// by another group member landing between the two calls can only make
	// the log end larger than what was committed, never the reverse; the
	// opposite order produced false "reset behind the consumer" alarms.
	fetched, err := client.OffsetFetch(ctx, &kafka.OffsetFetchRequest{
		GroupID: j.GroupID,
		Topics:  map[string][]int{j.ReadTopic: partitions},
	})
	if err != nil {
		return nil, err
	}

	if fetched.Error != nil {
		return nil, fetched.Error
	}

	offsetRequests := make([]kafka.OffsetRequest, 0, 2*len(partitions))
	for _, p := range partitions {
		offsetRequests = append(offsetRequests, kafka.FirstOffsetOf(p), kafka.LastOffsetOf(p))
	}

	listed, err := client.ListOffsets(ctx, &kafka.ListOffsetsRequest{
		Topics: map[string][]kafka.OffsetRequest{j.ReadTopic: offsetRequests},
	})
	if err != nil {
		return nil, err
	}

	logOffsets := map[int]kafka.PartitionOffsets{}
	for _, po := range listed.Topics[j.ReadTopic] {
		if po.Error != nil {
			return nil, po.Error
		}

		logOffsets[po.Partition] = po
	}

	stale := []kafka.OffsetCommit{}
	for _, p := range fetched.Topics[j.ReadTopic] {
		if p.Error != nil {
			return nil, p.Error
		}

		lo, ok := logOffsets[p.Partition]
		if !ok || !isStrandedOffset(p.CommittedOffset, lo.LastOffset) {
			continue
		}

		// Everything on the recreated partition is still unread: restart from
		// its first offset rather than skipping to the end.
		target := max(lo.FirstOffset, 0)
		log.LogErrorf(
			ctx,
			"consumer group %s offset %d on %s/%d is past the log end offset %d (topic recreated behind the consumer), resetting to %d",
			j.GroupID, p.CommittedOffset, j.ReadTopic, p.Partition, lo.LastOffset, target,
		)
		stale = append(stale, kafka.OffsetCommit{Partition: p.Partition, Offset: target})
	}

	return stale, nil
}

// commitGroupOffsets commits offsets for the group outside of any generation
// (GenerationID -1, the admin / simple-consumer path). The broker only accepts
// that while the consumer group is Empty, so this process's reader must have
// been closed (and have left the group) first; the retries cover the leave
// propagating. It cannot succeed while another member is in the group, e.g. a
// second pfcron instance consuming the same topic: the caller then backs off
// for repairCooldown instead of rebuilding the reader every readTimeout.
func (j *PfFlowJob) commitGroupOffsets(ctx context.Context, client *kafka.Client, commits []kafka.OffsetCommit) error {
	var err error
	for attempt := 0; attempt < 5; attempt++ {
		if attempt > 0 {
			time.Sleep(2 * time.Second)
		}

		var resp *kafka.OffsetCommitResponse
		resp, err = client.OffsetCommit(ctx, &kafka.OffsetCommitRequest{
			GroupID:      j.GroupID,
			GenerationID: -1,
			Topics:       map[string][]kafka.OffsetCommit{j.ReadTopic: commits},
		})
		if err == nil {
			for _, p := range resp.Topics[j.ReadTopic] {
				if p.Error != nil {
					err = p.Error
					break
				}
			}
		}

		if err == nil {
			return nil
		}

		log.LogWarnf(ctx, "resetting consumer group %s offsets (attempt %d): %s", j.GroupID, attempt+1, err.Error())
	}

	return err
}

func (j *PfFlowJob) Run() {
	ctx := context.Background()
	var r *kafka.Reader
	maxReconnectDelay := 60 * time.Second
	reconnectDelay := 1 * time.Second
	consecutiveErrors := 0

	closeReader := func() {
		if r == nil {
			return
		}

		if err := r.Close(); err != nil {
			log.LogErrorf(ctx, "failed to close kafka reader: %v", err)
		}

		r = nil
	}

	defer func() {
		closeReader()
		j.schedule.ran.Store(false)
	}()

	dialer := j.kafkaDialer()
	WaitForTopic(dialer, ctx, j.Brokers[0], j.ReadTopic)
	client := j.kafkaClient()

	nextStrandedCheck := time.Now().Add(strandedCheckInterval)
	var repairBlockedUntil time.Time

	// repairStrandedOffsets looks for group offsets past their partition's log
	// end and resets them. It returns true when a reset was attempted (the
	// reader is closed either way in that case).
	repairStrandedOffsets := func(reason string) bool {
		nextStrandedCheck = time.Now().Add(strandedCheckInterval)
		if time.Now().Before(repairBlockedUntil) {
			log.LogDebugf(ctx, "consumer group %s offset repair (%s) skipped, previous attempt failed, retrying after %s", j.GroupID, reason, repairBlockedUntil.Format(time.RFC3339))
			return false
		}

		stale, err := j.staleGroupOffsets(ctx, client)
		if err != nil {
			log.LogWarnf(ctx, "unable to check consumer group %s offsets (%s): %s", j.GroupID, reason, err.Error())
			return false
		}

		if len(stale) == 0 {
			return false
		}

		closeReader()
		if err := j.commitGroupOffsets(ctx, client, stale); err != nil {
			repairBlockedUntil = time.Now().Add(repairCooldown)
			log.LogErrorf(ctx, "failed to reset consumer group %s offsets: %s (the reset is only accepted while the group is empty; another consumer of %s in the same group, e.g. a second pfcron instance, prevents it; next attempt after %s)", j.GroupID, err.Error(), j.ReadTopic, repairBlockedUntil.Format(time.RFC3339))
			return true
		}

		log.LogInfof(ctx, "consumer group %s offsets reset on %d partition(s) of %s", j.GroupID, len(stale), j.ReadTopic)
		return true
	}

	for {
		// Create or recreate the reader
		if r == nil {
			log.LogInfof(ctx, "Connecting to Kafka brokers: %v, topic: %s, group: %s", j.Brokers, j.ReadTopic, j.GroupID)
			r = j.newReader(ctx, dialer)
		}

		// Use a timeout context to avoid blocking forever if Kafka is unresponsive
		readCtx, cancel := context.WithTimeout(ctx, readTimeout)
		m, err := r.ReadMessage(readCtx)
		cancel()
		if err != nil {
			// Check if it's just a timeout (no messages available) vs a real error.
			// kafka-go's ReadMessage wraps the error ("fetching message: %w"), so a
			// plain == comparison never matches — use errors.Is to unwrap.
			if errors.Is(err, context.DeadlineExceeded) {
				// No message for a whole readTimeout: either the topic is idle
				// or the group offset is stranded past the end of a recreated
				// topic, which kafka-go never recovers from on its own.
				if !repairStrandedOffsets("idle topic") {
					log.LogDebugf(ctx, "no message on %s for %s", j.ReadTopic, readTimeout)
				}

				continue
			}

			if errors.Is(err, kafka.OffsetOutOfRange) {
				// The broker told us directly that our offset does not exist
				// (OffsetOutOfRangeError in the reader config): repair now
				// instead of waiting for readTimeout of silence.
				log.LogErrorf(ctx, "consumer group %s offset out of range on %s: %s", j.GroupID, j.ReadTopic, err.Error())
				closeReader()
				repairStrandedOffsets("offset out of range")
				continue
			}

			consecutiveErrors++
			log.LogErrorf(ctx, "Error reading from Kafka (attempt %d): %s", consecutiveErrors, err.Error())

			// Close the current reader on error
			closeReader()

			// Exponential backoff with max delay
			if reconnectDelay < maxReconnectDelay {
				reconnectDelay = reconnectDelay * 2
				if reconnectDelay > maxReconnectDelay {
					reconnectDelay = maxReconnectDelay
				}
			}

			log.LogWarnf(ctx, "Reconnecting to Kafka in %v...", reconnectDelay)
			time.Sleep(reconnectDelay)
			continue
		}

		// Reset error counter and delay on successful read
		if consecutiveErrors > 0 {
			log.LogInfof(ctx, "Successfully reconnected to Kafka after %d errors", consecutiveErrors)
			consecutiveErrors = 0
			reconnectDelay = 1 * time.Second
		}

		// A partition can be stranded while the others keep delivering, in
		// which case the idle-read path above never fires; check periodically.
		// The message just read is processed below either way; if a reset
		// closed the reader, the next iteration recreates it.
		if time.Now().After(nextStrandedCheck) {
			repairStrandedOffsets("periodic check")
		}

		pfFlows := &PfFlows{}
		if err := json.Unmarshal(m.Value, pfFlows); err != nil {
			log.LogErrorf(ctx, "Error unmarshaling message: %v", err)
			continue
		}

		ChanPfFlow <- []*PfFlows{pfFlows}
		if j.fingerprintChan != nil {
			// Send the flows to the fingerprint channel
			j.fingerprintChan <- []*PfFlows{pfFlows}
		}
	}
}
