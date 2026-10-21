package pfqueueclient

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

type Task struct {
	TaskId string `json:"task_id"`
	Status int    `json:"status"`
}

type StatusUpdater struct {
	id          string
	key         string
	publishKey  string
	ttl         time.Duration
	finalized   bool
	redisClient *redis.Client
}

var statusUpdaterPool = sync.Pool{
	New: func() any {
		return &StatusUpdater{}
	},
}

func (u *StatusUpdater) updateStatus(ctx context.Context, data map[string]any) error {
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

func (u *StatusUpdater) saveResults(ctx context.Context, resultKey string, results any, status int, message string) error {
	data := map[string]any{
		"status":     status,
		"status_msg": message,
		resultKey:    results,
		"progress":   100,
	}
	return u.updateStatus(ctx, data)
}

func (u *StatusUpdater) Start(ctx context.Context) error {
	data := map[string]any{
		"status":     202,
		"status_msg": "In Progress",
		"progress":   0,
	}
	return u.updateStatus(ctx, data)
}

func (u *StatusUpdater) UpdateProgress(ctx context.Context, progress int, msg string) error {
	if progress > 100 {
		progress = 100
	} else if progress < 0 {
		progress = 0
	}
	data := map[string]any{
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
	data := map[string]any{
		"status_msg": msg,
	}
	if msg != "" {
		data["status_msg"] = msg
	}
	return u.updateStatus(ctx, data)
}

func (u *StatusUpdater) Failed(ctx context.Context, results any) error {
	data, err := json.Marshal(results)
	if err != nil {
		return err
	}
	if err := u.saveResults(ctx, "error", data, 400, "Failed"); err != nil {
		return err
	}
	u.finalized = true
	return nil
}

func (u *StatusUpdater) Complete(ctx context.Context, results any) error {
	data, err := json.Marshal(results)
	if err != nil {
		return err
	}
	if err := u.saveResults(ctx, "item", data, 200, "Complete"); err != nil {
		return err
	}
	u.finalized = true
	return nil
}

func (u *StatusUpdater) Cancel(ctx context.Context) error {
	return nil
}

func (u *StatusUpdater) reset(id string, ttl time.Duration, client *redis.Client) {
	u.id = id
	u.key = id + "-Status"
	u.publishKey = id + "-Status-Updates"
	u.ttl = ttl
	u.finalized = false
	u.redisClient = client
}

func NewStatusUpdater(id string, ttl time.Duration, redis *redis.Client) *StatusUpdater {
	u := statusUpdaterPool.Get().(*StatusUpdater)
	u.reset(id, ttl, redis)
	return u
}

func NewApiTask() Task {
	uuid, _ := uuid.NewV7()
	return Task{Status: 202, TaskId: "ApiTask:" + uuid.String()}
}

func PutStatusUpdater(u *StatusUpdater) {
	u.redisClient = nil
	statusUpdaterPool.Put(u)
}
