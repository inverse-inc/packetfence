package pfqueueclient

import (
	"context"

	"github.com/redis/go-redis/v9"
)

type DelayedQueue struct {
	DelayQueue, SubmitQueue string
	Batch                   int
}

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

func SetupConnection(ctx context.Context, conn *redis.Conn) error {
	exists, err := LUA_DELAY_JOBS_MOVE.Exists(ctx, conn).Result()
	if err != nil {
		return nil
	}

	if len(exists) > 0 && exists[0] {
		return nil
	}

	return LUA_DELAY_JOBS_MOVE.Load(ctx, conn).Err()
}

func (dq *DelayedQueue) Run(ctx context.Context, client *redis.Client) error {
	t, err := client.Time(ctx).Result()
	if err != nil {
		return err
	}

	return LUA_DELAY_JOBS_MOVE.Run(
		ctx,
		client,
		[]string{dq.DelayQueue, dq.SubmitQueue},
		t.UnixMilli(),
		dq.Batch,
	).Err()
}
