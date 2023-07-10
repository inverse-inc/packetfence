package maint

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/inverse-inc/go-utils/log"
)

type FlushRadiusAuditLogJob struct {
	Task
	Batch   int64
	Timeout time.Duration
	redis   *redis.Client
}

func NewFlushRadiusAuditLogJob(config map[string]interface{}) JobSetupConfig {
	return &FlushRadiusAuditLogJob{
		Task:    SetupTask(config),
		Batch:   int64(config["batch"].(float64)),
		Timeout: time.Duration((config["timeout"].(float64))) * time.Second,
		redis:   redisClient(),
	}
}

func (j *FlushRadiusAuditLogJob) Run() {
	start := time.Now()
	rows_affected := 0
	i := 0
	ctx := context.Background()
	for {
		i++
		var data *redis.StringSliceCmd
		j.redis.TxPipelined(ctx, func(pipe redis.Pipeliner) error {
			data = pipe.LRange(ctx, "RADIUS_AUDIT_LOG", 0, j.Batch-1)
			pipe.LTrim(ctx, "RADIUS_AUDIT_LOG", j.Batch, -1)
			return nil
		})

		if err := data.Err(); err != nil {
			log.LogError(ctx, fmt.Sprintf("%s error running: %s", j.Name(), err.Error()))
			break
		}

		a := data.Val()
		if len(a) == 0 {
			break
		}

		rows_affected += len(a)
		jsonStr := "[" + strings.Join(a, ",") + "]"
		var entries [][]interface{} = make([][]interface{}, len(a))
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

func (j *FlushRadiusAuditLogJob) flushLogs(entries [][]interface{}) error {
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

const RADIUS_AUDIT_LOG_COLUMN_COUNT = 37

/*
   query = "INSERT INTO radius_audit_log \
     (
		mac, ip, computer_name,
		user_name, stripped_user_name, realm, event_type,
		switch_id, switch_mac, switch_ip_address,
		radius_source_ip_address, called_station_id, calling_station_id,
		nas_port_type, ssid, nas_port_id,
		ifindex, nas_port, connection_type,
		nas_ip_address, nas_identifier, auth_status,
		reason, auth_type, eap_type,
		role, node_status, profile,
		source, auto_reg, is_phone,
		pf_domain, uuid, radius_request,
		radius_reply, request_time, radius_ip
   )\
     VALUES \
     ( '%{request:Calling-Station-Id}', '%{request:Framed-IP-Address}', '%{%{control:PacketFence-Computer-Name}:-N/A}', '%{request:User-Name}',\
       '%{request:Stripped-User-Name}', '%{request:Realm}', 'Radius-Access-Request',\
       '%{%{control:PacketFence-Switch-Id}:-N/A}', '%{%{control:PacketFence-Switch-Mac}:-N/A}', '%{%{control:PacketFence-Switch-Ip-Address}:-N/A}',\
       '%{Packet-Src-IP-Address}', '%{request:Called-Station-Id}', '%{request:Calling-Station-Id}',\
       '%{request:NAS-Port-Type}', '%{request:Called-Station-SSID}', '%{request:NAS-Port-Id}',\
       '%{%{control:PacketFence-IfIndex}:-N/A}', '%{request:NAS-Port}', '%{%{control:PacketFence-Connection-Type}:-N/A}',\
       '%{request:NAS-IP-Address}', '%{request:NAS-Identifier}', 'Accept',\
       '%{request:Module-Failure-Message}', '%{control:Auth-Type}', '%{request:EAP-Type}',\
       '%{%{control:PacketFence-Role}:-N/A}', '%{%{control:PacketFence-Status}:-N/A}', '%{%{control:PacketFence-Profile}:-N/A}',\
       '%{%{control:PacketFence-Source}:-N/A}', '%{%{control:PacketFence-AutoReg}:-0}', '%{%{control:PacketFence-IsPhone}:-0}',\
       '%{request:PacketFence-Domain}', '', '%{pairs:&request:[*]}','%{pairs:&reply:[*]}', '%{control:PacketFence-Request-Time}', '%{request:PacketFence-Radius-Ip}')"
*/

func (j *FlushRadiusAuditLogJob) buildQuery(entries [][]interface{}) (string, []interface{}, error) {
	sql := `
INSERT INTO radius_audit_log
	(
		mac, ip, computer_name,
		user_name, stripped_user_name, realm, event_type,
		switch_id, switch_mac, switch_ip_address,
		radius_source_ip_address, called_station_id, calling_station_id,
		nas_port_type, ssid, nas_port_id,
		ifindex, nas_port, connection_type,
		nas_ip_address, nas_identifier, auth_status,
		reason, auth_type, eap_type,
		role, node_status, profile,
		source, auto_reg, is_phone,
		pf_domain, uuid, radius_request,
		radius_reply, request_time, radius_ip
   )
VALUES `
	bind := "(?" + strings.Repeat(",?", RADIUS_AUDIT_LOG_COLUMN_COUNT-1) + ")"
	sql += bind + strings.Repeat(","+bind, len(entries)-1)
	args := make([]interface{}, 0, len(entries)*RADIUS_AUDIT_LOG_COLUMN_COUNT)
	for _, e := range entries {
		args = append(args, j.argsFromEntry(e)...)
	}

	return sql, args, nil
}

func (j *FlushRadiusAuditLogJob) argsFromEntry(entry []interface{}) []interface{} {
	args := make([]interface{}, RADIUS_AUDIT_LOG_COLUMN_COUNT)
	var request, reply, control map[string]interface{}
	request = entry[1].(map[string]interface{})
	reply = entry[2].(map[string]interface{})
	control = entry[3].(map[string]interface{})
	args[0] = interfaceToStr(request["Calling-Station-Id"], "N/A")
	args[1] = interfaceToStr(request["Framed-IP-Address"], "N/A")
	args[2] = interfaceToStr(request["PacketFence-Computer-Name"], "N/A")
	args[3] = interfaceToStr(request["User-Name"], "N/A")
	args[4] = interfaceToStr(request["Stripped-User-Name"], "N/A")
	args[5] = interfaceToStr(request["Realm"], "N/A")
	args[6] = "Radius-Access-Request"
	args[7] = interfaceToStr(control["PacketFence-Switch-Id"], "N/A")
	args[8] = interfaceToStr(control["PacketFence-Switch-Mac"], "N/A")
	args[9] = interfaceToStr(control["PacketFence-Switch-Ip-Address"], "N/A")
	args[10] = interfaceToStr(control["Packet-Src-IP-Address"], "N/A")
	args[11] = interfaceToStr(request["Called-Station-Id"], "")
	args[12] = interfaceToStr(request["Calling-Station-Id"], "")
	args[13] = interfaceToStr(request["NAS-Port-Type"], "")
	args[14] = interfaceToStr(request["Called-Station-SSID"], "")
	args[15] = interfaceToStr(request["NAS-Port-Id"], "N/A")
	args[16] = interfaceToStr(control["PacketFence-IfIndex"], "N/A")
	args[17] = interfaceToStr(request["NAS-Port"], "")
	args[18] = interfaceToStr(control["PacketFence-Connection-Type"], "N/A")
	args[19] = interfaceToStr(request["NAS-IP-Address"], "")
	args[20] = interfaceToStr(request["NAS-Identifier"], "")
	args[21] = interfaceToStr(entry[0], "accept")
	args[22] = interfaceToStr(request["Module-Failure-Message"], "")
	args[23] = interfaceToStr(control["Auth-Type"], "")
	args[24] = interfaceToStr(request["EAP-Type"], "")
	args[25] = interfaceToStr(control["PacketFence-Role"], "N/A")
	args[26] = interfaceToStr(control["PacketFence-Status"], "N/A")
	args[27] = interfaceToStr(control["PacketFence-Profile"], "N/A")
	args[28] = interfaceToStr(control["PacketFence-Source"], "N/A")
	args[29] = interfaceToStr(control["PacketFence-AutoReg"], "0")
	args[30] = interfaceToStr(control["PacketFence-IsPhone"], "0")
	args[31] = interfaceToStr(request["PacketFence-Domain"], "")
	args[32] = ""
	args[33] = formatRequest(request)
	args[34] = formatRequest(reply)
	args[35] = interfaceToStr(control["PacketFence-Request-Time"], "")
	args[36] = interfaceToStr(request["PacketFence-Radius-Ip"], "")
	return args
}

func formatRequest(request map[string]interface{}) string {
	parts := []string{}
	for k, v := range request {
		parts = append(parts, k+" : "+formatRequestValue(v))
	}

	return strings.Join(parts, ",\n")
}

func formatRequestValue(i interface{}) string {
	switch v := i.(type) {
	case string:
		return v
	case int8:
		return strconv.FormatInt(int64(v), 10)
	case int16:
		return strconv.FormatInt(int64(v), 10)
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	case uint8:
		return strconv.FormatUint(uint64(v), 10)
	case uint16:
		return strconv.FormatUint(uint64(v), 10)
	case uint32:
		return strconv.FormatUint(uint64(v), 10)
	case uint64:
		return strconv.FormatUint(v, 10)
	case int:
		return strconv.Itoa(v)
	case map[string]interface{}:
		val := formatRequestValue(v["value"])
		return val
	default:
		return ""
	}
}

func interfaceToStr(i interface{}, defaultStr string) string {
	if str, found := i.(string); found {
		return str
	}

	return defaultStr
}
