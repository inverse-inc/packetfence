package pfqueueclient

import (
	"context"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
)

type StatusUpdater struct {
	id          string
	key         string
	publishKey  string
	ttl         time.Duration
	finalized   bool
	redisClient *redis.Client
}

func (u *StatusUpdater) updateStatus(ctx context.Context, data map[string]interface{}) error {
	if u.finalized {
		return nil
	}

	_, err := u.redisClient.Pipelined(
		ctx,
		func(pipe redis.Pipeliner) error {
			pipe.HSet(ctx, u.key, data)
			pipe.Expire(ctx, u.key, u.ttl)
			pipe.Del(ctx, u.publishKey)
			pipe.RPush(ctx, u.publishKey, 1)
			return nil
		},
	)

	return err
}

func (u *StatusUpdater) saveResults(ctx context.Context, resultKey string, results interface{}, status int, message string) error {
	data := map[string]interface{}{
		"status":     status,
		"status_msg": message,
		resultKey:    results,
		"progress":   100,
	}

	return u.updateStatus(ctx, data)
}

func (u *StatusUpdater) Start(ctx context.Context) error {
	data := map[string]interface{}{
		"status":     202,
		"status_msg": "In Progress",
		"progress":   0,
	}

	return u.updateStatus(ctx, data)
}

func (u *StatusUpdater) UpdateProgress(ctx context.Context, progress int, msg string) error {

	if progress > 99 {
		progress = 99
	} else if progress < 0 {
		progress = 0
	}

	data := map[string]interface{}{
		"progress": progress,
	}

	if msg != "" {
		data["status_msg"] = msg
	}

	return u.updateStatus(ctx, data)
}

func (u *StatusUpdater) UpdateMessage(ctx context.Context, msg string) error {

	if msg == "" {
		return nil
	}

	data := map[string]interface{}{
		"status_msg": msg,
	}

	if msg != "" {
		data["status_msg"] = msg
	}

	return u.updateStatus(ctx, data)
}

func (u *StatusUpdater) Failed(ctx context.Context, results interface{}) error {
	if err := u.saveResults(ctx, "error", results, 400, "Failed"); err != nil {
		return err
	}
	u.finalized = true
	return nil
}

func (u *StatusUpdater) Complete(ctx context.Context, results interface{}) error {
	if err := u.saveResults(ctx, "item", results, 200, "Complete"); err != nil {
		return err
	}
	u.finalized = true
	return nil
}

var statusUpdaterPool = sync.Pool{
	New: func() interface{} {
		return &StatusUpdater{}
	},
}

func (u *StatusUpdater) reset(id string, ttl time.Duration) {
	u.id = id
	u.key = id + "-Status"
	u.publishKey = id + "-Status-Update"
	u.ttl = ttl
	u.finalized = false
}

func NewStatusUpdater(id string, ttl time.Duration, redis *redis.Client) *StatusUpdater {
	u := statusUpdaterPool.Get().(*StatusUpdater)
	u.reset(id, ttl)
	return u
}

func PutStatusUpdater(u *StatusUpdater) {
	u.redisClient = nil
	statusUpdaterPool.Put(u)
}
