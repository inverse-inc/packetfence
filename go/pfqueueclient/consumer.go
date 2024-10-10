package pfqueueclient

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"syscall"
	"time"

	"github.com/redis/go-redis/v9"
)

type Consumer struct {
	name  string
	redis *redis.Client
	conn  *BackendConn
}

func NewConsumer(redis *redis.Client, name string) (*Consumer, error) {
	conn, err := NewBackendConn(name)
	if err != nil {
		return nil, err
	}

	return &Consumer{name: name, redis: redis, conn: conn}, nil
}

func (c *Consumer) Close() {
	c.conn.Close()
}

const PFQUEUE_COUNTER = "TaskCounters"
const PFQUEUE_EXPIRED_COUNTER = "ExpiredCounters"

type TaskInfo struct {
	Data         []byte `redis:"data"`
	StatusUpdate int    `redis:"status_update"`
}

func (c *Consumer) ProcessNextQueueItem(ctx context.Context, queues []string) error {
	taskID, err := c.nextTaskID(ctx, queues)
	if err != nil {
		return err
	}

	var statusUpdater *StatusUpdater = nil

	counterID := getTaskCounterId(taskID)
	pipe := c.redis.Pipeline()
	pipe.HIncrBy(ctx, PFQUEUE_COUNTER, counterID, -1)
	taskInfoOut := pipe.HGetAll(ctx, taskID)
	pipe.Del(ctx, taskID)
	_, err = pipe.Exec(ctx)
	if err != nil {
		return err
	}

	var taskInfo TaskInfo
	if err := taskInfoOut.Scan(&taskInfo); err != nil {
		return err
	}

	if taskInfo.Data == nil {
		pipe.HIncrBy(ctx, PFQUEUE_EXPIRED_COUNTER, counterID, -1)
		return fmt.Errorf("Data not found for task %s\n", taskID)
	}

	if taskInfo.StatusUpdate != 0 {
		statusUpdater = NewStatusUpdater(taskID, time.Second*60, c.redis)
		defer PutStatusUpdater(statusUpdater)
		statusUpdater.Start(ctx)
	}

	retry := 3
	for retry > 0 {
		out, err := c.conn.Send(taskInfo.Data)
		retry--
		if err != nil {
			if errors.Is(err, syscall.EPIPE) {
				c.conn.Close()
				conn, err2 := NewBackendConn(c.name)
				if err2 == nil {
					c.conn = conn
					continue
				}
			}

			if statusUpdater != nil {
				data, _ := json.Marshal(out)
				statusUpdater.Failed(ctx, data)
			}

			return err
		}

		if statusUpdater != nil && out != nil {
			data, _ := json.Marshal(out)
			statusUpdater.Complete(ctx, data)
		}

		break
	}

	return nil
}

func (c *Consumer) nextTaskID(ctx context.Context, queues []string) (string, error) {
	var taskID = ""
	if len(queues) == 0 {
		return "", errors.New("No queues")
	}

	if len(queues) == 1 {
		taskID, _ = c.redis.RPop(ctx, queues[0]).Result()
	}

	if taskID != "" {
		return taskID, nil
	}

	val, err := c.redis.BRPop(ctx, time.Second*1, queues...).Result()
	if err != nil {
		return "", err
	}

	return val[1], nil
}

func getTaskCounterId(id string) string {
	p := strings.SplitN(id, ":", 3)
	return p[2]
}

func setupConnection(ctx context.Context, conn *redis.Conn) error {
	return nil
}
