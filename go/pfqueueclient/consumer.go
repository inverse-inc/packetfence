package pfqueueclient

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
)

type Consumer struct {
	redis *redis.Client
	conn  *BackendConn
}

func NewConsumer(redis *redis.Client, name string) (*Consumer, error) {
	conn, err := NewBackendConn(name)
	if err != nil {
		return nil, err
	}

	return &Consumer{redis: redis, conn: conn}, nil
}

func (c *Consumer) Close() {
	c.conn.Close()
}

const PFQUEUE_COUNTER = "TaskCounters"
const PFQUEUE_EXPIRED_COUNTER = "ExpiredCounters"

/*

This lua script gets all the job id from a zset with a timestamp less the one passed
Then push all the job ids the work queue
It is called like the following
EVAL LUA_DELAY_JOBS_MOVE 2 DELAY_ZSET JOB_QUEUE TIMESTAMP BATCH

*/

var LUA_DELAY_JOBS_MOVE = redis.NewScript(`local task_ids = redis.call("ZRANGEBYSCORE",KEYS[1],'-inf',ARGV[1],'LIMIT',0,ARGV[2]);
    if table.getn(task_ids) > 0 then
        redis.call("LPUSH",KEYS[2],unpack(task_ids));
        redis.call("ZREM",KEYS[1],unpack(task_ids));
    end
`,
)

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

	out, err := c.conn.Send(taskInfo.Data)
	if err != nil {
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
		return "", nil
	}

	return val[1], nil
}

func (c *Consumer) ProcessDelayedJobs(ctx context.Context, delay_queue, submit_queue string, time_limit, batch int) {
	LUA_DELAY_JOBS_MOVE.Run(ctx, c.redis, []string{delay_queue, submit_queue}, time_limit, batch)
}

func getTaskCounterId(id string) string {
	p := strings.SplitN(id, ":", 3)
	return p[2]
}

func setupConnection(ctx context.Context, conn *redis.Conn) error {
	return nil
}
