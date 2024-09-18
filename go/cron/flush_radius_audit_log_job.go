package maint

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/util"
	"github.com/redis/go-redis/v9"
)

type FlushRadiusAuditLogJob struct {
	Task
	Batch   int64
	Timeout time.Duration
	redis   *redis.Client
}

const hextable = "0123456789ABCDEF"

func NewFlushRadiusAuditLogJob(config map[string]interface{}) JobSetupConfig {
	return &FlushRadiusAuditLogJob{
		Task:    SetupTask(config),
		Batch:   int64(config["batch"].(float64)),
		Timeout: time.Duration((config["timeout"].(float64))) * time.Second,
		redis:   getRedisClient(),
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

		var entries [][]interface{} = make([][]interface{}, 0, len(a))
		for _, jsonStr := range a {
			if jsonStr == "" {
				continue
			}
			var entry []interface{} = make([]interface{}, 4)
			if jsonStr[0] != '[' {
				s, err := base64.StdEncoding.DecodeString(jsonStr)
				if err != nil {
					log.LogError(ctx, fmt.Sprintf("%s error running: %s", j.Name(), err.Error()))
					continue
				}

				jsonStr = string(s)
			}

			err := json.Unmarshal([]byte(jsonStr), &entry)
			if err != nil {
				log.LogError(ctx, fmt.Sprintf("%s error running: %s", j.Name(), err.Error()))
				continue
			}

			entries = append(entries, entry)
		}

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
		created_at, mac, ip, computer_name,
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
	bind := "(NOW(), ?" + strings.Repeat(",?", RADIUS_AUDIT_LOG_COLUMN_COUNT-1) + ")"
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
	args[2] = formatRequestValue(request["PacketFence-Computer-Name"], "N/A")
	args[0] = formatRequestValue(request["Calling-Station-Id"], "N/A")
	args[1] = formatRequestValue(request["Framed-IP-Address"], "N/A")
	args[3] = formatRequestValue(request["User-Name"], "N/A")
	args[4] = formatRequestValue(request["Stripped-User-Name"], "N/A")
	args[5] = formatRequestValue(request["Realm"], "N/A")
	args[6] = "Radius-Access-Request"
	args[7] = formatRequestValue(control["PacketFence-Switch-Id"], "N/A")
	args[8] = formatRequestValue(control["PacketFence-Switch-Mac"], "N/A")
	args[9] = formatRequestValue(control["PacketFence-Switch-Ip-Address"], "N/A")
	args[10] = formatRequestValue(control["Packet-Src-IP-Address"], "N/A")
	args[11] = formatRequestValue(request["Called-Station-Id"], "")
	args[12] = formatRequestValue(request["Calling-Station-Id"], "")
	args[13] = formatRequestValue(request["NAS-Port-Type"], "")
	args[14] = formatRequestValue(request["Called-Station-SSID"], "")
	args[15] = formatRequestValue(request["NAS-Port-Id"], "N/A")
	args[16] = formatRequestValue(control["PacketFence-IfIndex"], "N/A")
	args[17] = formatRequestValue(request["NAS-Port"], "")
	args[18] = formatRequestValue(control["PacketFence-Connection-Type"], "N/A")
	args[19] = formatRequestValue(request["NAS-IP-Address"], "")
	args[20] = formatRequestValue(request["NAS-Identifier"], "")
	args[21] = formatRequestValue(entry[0], "Accept")
	args[22] = formatRequestValue(request["Module-Failure-Message"], "")
	args[23] = formatRequestValue(control["Auth-Type"], "")
	args[24] = formatRequestValue(request["EAP-Type"], "")
	args[25] = formatRequestValue(control["PacketFence-Role"], "N/A")
	args[26] = formatRequestValue(control["PacketFence-Status"], "N/A")
	args[27] = formatRequestValue(control["PacketFence-Profile"], "N/A")
	args[28] = formatRequestValue(control["PacketFence-Source"], "N/A")
	args[29] = formatRequestValue(control["PacketFence-AutoReg"], "0")
	args[30] = formatRequestValue(control["PacketFence-IsPhone"], "0")
	args[31] = formatRequestValue(request["PacketFence-Domain"], "")
	args[32] = ""
	args[33] = formatRequest(request)
	args[34] = formatRequest(reply)
	args[35] = formatRequestValue(control["PacketFence-Request-Time"], "")
	args[36] = formatRequestValue(request["PacketFence-Radius-Ip"], "")
	return args
}

func formatRequest(request map[string]interface{}) string {
	parts := []string{}
	keys := util.MapKeys(request)
	sort.Strings(keys)
	for _, k := range keys {
		parts = append(parts, formatRequestKeyValue(k, request[k]))
	}

	return escapeRadiusRequest(strings.Join(parts, ",\n"))
}

func formatRequestKeyValue(key string, value interface{}) string {
	if val, ok := value.(map[string]interface{}); ok {
		value = val["value"]
	}

	if val, ok := value.([]interface{}); ok {
		if len(val) > 1 {
			parts := make([]string, 0, len(val))
			for _, p := range val {
				parts = append(parts, formatRequestKeyValue(key, p))
			}
			return strings.Join(parts, ",\n")
		}

	}

	return key + ` = "` + formatRequestValue(value, "") + `"`
}

func formatRequestValue(i interface{}, defaultValue string) string {
	switch v := i.(type) {
	case string:
		return v
	case float64:
		return strconv.FormatFloat(v, 'g', -1, 64)
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
		val := formatRequestValue(v["value"], defaultValue)
		return val
	case []interface{}:
		if len(v) > 0 {
			return formatRequestValue(v[0], defaultValue)
		}
	default:
		return defaultValue
	}
	return defaultValue
}

func escapeRadiusRequest(s string) string {
	size := 0
	for _, c := range []byte(s) {
		if shouldEscape(c) {
			size += 3
		} else {
			size++
		}
	}

	if size == len(s) {
		return s
	}

	out := make([]byte, size)
	j := 0
	for _, c := range []byte(s) {
		if shouldEscape(c) {
			out[j] = '='
			out[j+1] = hextable[c>>4]
			out[j+2] = hextable[c&0x0f]
			j += 3
		} else {
			out[j] = c
			j++
		}
	}

	return string(out)
}

func shouldEscape(c byte) bool {
	return strings.IndexByte("@abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_: /", c) == -1
}

func interfaceToStr(i interface{}, defaultStr string) string {
	if str, found := i.(string); found {
		return str
	}

	return defaultStr
}
