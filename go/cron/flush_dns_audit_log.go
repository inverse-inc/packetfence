package maint

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/common"
	"github.com/redis/go-redis/v9"
)

type FlushDNSAuditLog struct {
	Task
	Batch   int64
	Timeout time.Duration
	redis   *redis.Client
}

func NewFlushDNSAuditLog(config map[string]interface{}) JobSetupConfig {
	return &FlushDNSAuditLog{
		Task:    SetupTask(config),
		Batch:   int64(config["batch"].(float64)),
		Timeout: time.Duration((config["timeout"].(float64))) * time.Second,
		redis:   getRedisClient(),
	}
}

func (j *FlushDNSAuditLog) Run() {
	start := time.Now()
	rows_affected := 0
	i := 0
	ctx := context.Background()
	for {
		i++
		var data *redis.StringSliceCmd
		j.redis.TxPipelined(ctx, func(pipe redis.Pipeliner) error {
			data = pipe.LRange(ctx, "DNS_AUDIT_LOG", 0, j.Batch-1)
			pipe.LTrim(ctx, "DNS_AUDIT_LOG", j.Batch, -1)
			return nil
		})

		if err := data.Err(); err != nil {
			log.LogError(ctx, err.Error())
			break
		}

		a := data.Val()
		if len(a) == 0 {
			break
		}

		rows_affected += len(a)
		jsonStr := "[" + strings.Join(a, ",") + "]"
		var entries []common.DNSAuditLog = make([]common.DNSAuditLog, len(a))
		json.Unmarshal([]byte(jsonStr), &entries)
		j.flushLogs(entries)
		if time.Now().Sub(start) > j.Timeout {
			break
		}
	}

	if rows_affected > 0 {
		log.LogInfo(ctx, fmt.Sprintf("%s called times %d and handled %d items", j.Name(), i, rows_affected))
	}
}

func (j *FlushDNSAuditLog) flushLogs(entries []common.DNSAuditLog) error {
	ctx := context.Background()
	sql, args, err := j.buildQuery(entries)
	if err != nil {
		return err
	}

	db, err := getDb()
	if err != nil {
		return err
	}

	res, err := db.ExecContext(
		ctx,
		sql,
		args...,
	)

	if err != nil {
		return err
	}

	rows, err := res.RowsAffected()
	if err != nil {
		return err
	}

	log.LogInfo(ctx, fmt.Sprintf("Flushed %d radius_audit_log", rows))
	return nil
}

func (j *FlushDNSAuditLog) buildQuery(entries []common.DNSAuditLog) (string, []interface{}, error) {
	sql := `
		INSERT INTO dns_audit_log
		(
			ip, mac, qname, qtype, scope, answer
		)
		VALUES `
	bind := "(?" + strings.Repeat(",?", 5) + ")"
	sql += bind + strings.Repeat(","+bind, len(entries)-1)
	args := make([]interface{}, 0, len(entries)*6)
	for _, e := range entries {
		args = append(args, j.argsFromEntry(e)...)
	}

	return sql, args, nil
}

func (j *FlushDNSAuditLog) argsFromEntry(e common.DNSAuditLog) []interface{} {
	return []interface{}{
		e.Ip,
		e.Mac,
		e.Qname,
		e.Qtype,
		e.Scope,
		e.Answer,
	}
}
