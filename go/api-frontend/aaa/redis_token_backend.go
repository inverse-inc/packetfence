package aaa

import (
	"context"
	"encoding/json"
	"github.com/go-redis/redis/v8"
	"time"
)

type RedisTokenBackend struct {
	redis             *redis.Client
	maxExpiration     time.Duration
	inActivityTimeout time.Duration
}

func NewRedisTokenBackend(expiration time.Duration, maxExpiration time.Duration, args []string) *RedisTokenBackend {
	return &RedisTokenBackend{
		redis: redis.NewClient(&redis.Options{
			Addr:     "localhost:6379",
			Password: "", // no password set
			DB:       0,  // use default DB
		}),
		inActivityTimeout: expiration,
		maxExpiration:     maxExpiration,
	}
}

func (rtb *RedisTokenBackend) tokenKey(token string) string {
	return tokenKey(rtb, token)
}

func (rtb *RedisTokenBackend) AdminActionsForToken(token string) map[string]bool {
	return AdminActionsForToken(rtb, token)
}

func (rtb *RedisTokenBackend) TokenInfoForToken(token string) (*TokenInfo, time.Time) {
	ctx := context.Background()
	key := rtb.tokenKey(token)
	pipe := rtb.redis.Pipeline()
	get := pipe.Get(ctx, key)
	expire := pipe.PTTL(ctx, key)
	_, err := pipe.Exec(ctx)
	if err != nil {
		return nil, time.Unix(0, 0)
	}

	jsonStr, err := get.Result()
	if err != nil {
		return nil, time.Unix(0, 0)
	}

	dur, err := expire.Result()
	if err != nil {
		return nil, time.Unix(0, 0)
	}

	expiration := time.Now().Add(dur)

	ti := TokenInfo{}
	err = json.Unmarshal([]byte(jsonStr), &ti)
	if err != nil {
		return nil, time.Unix(0, 0)
	}

	return ValidTokenExpiration(&ti, expiration, rtb.maxExpiration)
}

func (rtb *RedisTokenBackend) StoreTokenInfo(token string, ti *TokenInfo) error {
	ti.CreatedAt = time.Now()
	data, err := json.Marshal(ti)
	if err != nil {
		return err
	}

	return rtb.redis.SetEX(context.Background(), rtb.tokenKey(token), data, rtb.inActivityTimeout).Err()
}

func (rtb *RedisTokenBackend) TokenIsValid(token string) bool {
	count, err := rtb.redis.Exists(context.Background(), rtb.tokenKey(token)).Result()
	return err == nil && count == 1
}

func (rtb *RedisTokenBackend) TouchTokenInfo(token string) {
	_, _ = rtb.redis.Expire(context.Background(), rtb.tokenKey(token), rtb.inActivityTimeout).Result()
}

var _ TokenBackend = (*RedisTokenBackend)(nil)
