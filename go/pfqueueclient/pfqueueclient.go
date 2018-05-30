package pfqueueclient

import (
	"context"
	"github.com/Sereal/Sereal/Go/sereal"
	"github.com/inverse-inc/packetfence/go/redisclient"
	"github.com/mediocregopher/radix.v2/redis"
	"github.com/nu7hatch/gouuid"
	"time"
)

type PfQueueClient struct {
}

type PfQueueEncoder interface {
    Marshal(interface{}) ([]byte, error)
}

func NewPfQueueClient() *PfQueueClient {
	return &PfQueueClient{}
}

const DefaultExpiration = time.Minute * 5

func (c *PfQueueClient) Submit(ctx context.Context, queue, task_type string, task_data interface{}) (string, error) {
	return c.SubmitWithExpiration(ctx, queue, task_type, task_data, DefaultExpiration)
}

func (c *PfQueueClient) Encoder() PfQueueEncoder {
	encoder := sereal.NewEncoderV3()
	encoder.PerlCompat = true
	return encoder
}

func (c *PfQueueClient) SubmitWithExpiration(ctx context.Context, queue, task_type string, task_data interface{}, expire_in time.Duration) (string, error) {
	queue_name := c.FormatQueueName(queue)
	taskCounterId := c.taskCounterId(queue_name, task_type, task_data)
	id, err := c.generateId(taskCounterId)
	if err != nil {
		return "", nil
	}

	redisClient, err := redisclient.GetPfQueueRedisClient(context.Background())
	if err != nil {
		return "", nil
	}

	defer redisclient.PutPfQueueRedisClient(redisClient)
	encoder := c.Encoder()
	data, err := encoder.Marshal([]interface{}{task_type, task_data})
	if err != nil {
		return "", nil
	}

	redisClient.PipeAppend("MULTI")
	redisClient.PipeAppend("HMSET", id, "expire", expire_in, "data", data)
	redisClient.PipeAppend("EXPIRE", id, expire_in)
	redisClient.PipeAppend("HINCRBY", "TaskCounters", taskCounterId, 1)
	redisClient.PipeAppend("LPUSH", queue_name, id)
	redisClient.PipeAppend("EXEC")
	var resp *redis.Resp
	for resp = redisClient.PipeResp(); resp.Err == nil; resp = redisClient.PipeResp() {
	}

	if resp.Err != redis.ErrPipelineEmpty {
		return id, resp.Err
	}

	return id, nil
}

func (c *PfQueueClient) FormatQueueName(q string) string {
	return "Queue:" + q
}

func (c *PfQueueClient) generateId(taskCounterId string) (string, error) {
	u4, err := uuid.NewV4()
	if err != nil {
		return "", err
	}

	return "Task:" + u4.String() + ":" + taskCounterId, nil
}

func (c *PfQueueClient) taskCounterId(queue, task_type string, task_data interface{}) string {
	counter_id := queue + ":" + task_type
	if task_type == "api" {
		if array, ok := task_data.([]interface{}); ok {
			counter_id += ":" + array[0].(string)
		}
	}

	return counter_id
}
