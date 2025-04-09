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

		log.LogInfof(ctx, "%s processing %d entries", j.Name(), len(a))
		rows_affected += len(a)

		var entries [][]interface{} = make([][]interface{}, 0, len(a))
		for _, jsonStr := range a {
			if jsonStr == "" {
				log.LogInfof(ctx, "%s empty entry skipped", j.Name())
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
			jsonStr = strings.Replace(jsonStr, "\\", "", -1)
			err := json.Unmarshal([]byte(jsonStr), &entry)

			if err != nil {
				log.LogError(ctx, fmt.Sprintf("%s error running: %s jsonStr '%s'", j.Name(), err.Error(), jsonStr))
				continue
			}

			entries = append(entries, entry)
		}

		if len(entries) == 0 {
			log.LogErrorf(ctx, "%s error processing some entries", j.Name())
			continue
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

	// REPLACE in node_tls
	sqlTLS, argsTLS, run := j.buildQueryTLS(entries)
	if run {
		res, err = db.ExecContext(
			ctx,
			sqlTLS,
			argsTLS...,
		)

		if err != nil {
			return fmt.Errorf("Error with %s\n%v: %w", sqlTLS, argsTLS, err)
		}

		_, err = res.RowsAffected()
		if err != nil {
			return err
		}

	} else {
		fmt.Printf("Zero Args\n")
	}

	log.LogInfo(ctx, fmt.Sprintf("Flushed %d radius_audit_log", rows))
	return nil
}

const RADIUS_AUDIT_LOG_COLUMN_COUNT = 37
const NODE_TLS_COLUMN_COUNT = 19

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
	request = parseRequestArgs(request)
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

func (j *FlushRadiusAuditLogJob) buildQueryTLS(entries [][]interface{}) (string, []interface{}, bool) {
	args := j.argsFromEntriesForTLS(entries)
	if len(args) == 0 {
		return "", nil, false
	}

	sql := `
INSERT INTO node_tls
	(
		mac, TLSCertSerial, TLSCertExpiration, TLSCertValidSince,
		TLSCertSubject, TLSCertIssuer, TLSCertCommonName,
		TLSCertSubjectAltNameEmail, TLSClientCertSerial,
		TLSClientCertExpiration, TLSClientCertValidSince,
		TLSClientCertSubject, TLSClientCertIssuer,
		TLSClientCertCommonName, TLSClientCertSubjectAltNameEmail,
		TLSClientCertX509v3ExtendedKeyUsage,
		TLSClientCertX509v3SubjectKeyIdentifier,
		TLSClientCertX509v3AuthorityKeyIdentifier,
		TLSClientCertX509v3ExtendedKeyUsageOID
	)
VALUES `
	bind := "( ?" + strings.Repeat(",?", NODE_TLS_COLUMN_COUNT-1) + ")"
	sql += bind + strings.Repeat(","+bind, (len(args)/NODE_TLS_COLUMN_COUNT)-1)
	sql += `
	 ON DUPLICATE KEY UPDATE TLSCertSerial = VALUES(TLSCertSerial),
	        TLSCertExpiration = VALUES(TLSCertExpiration), TLSCertValidSince = VALUES(TLSCertValidSince),
			TLSCertSubject = VALUES(TLSCertSubject), TLSCertIssuer = VALUES(TLSCertIssuer), TLSCertCommonName = VALUES( TLSCertCommonName),
			TLSCertSubjectAltNameEmail = VALUES(TLSCertSubjectAltNameEmail), TLSClientCertSerial = VALUES(TLSClientCertSerial),
			TLSClientCertExpiration = VALUES(TLSClientCertExpiration), TLSClientCertValidSince = VALUES(TLSClientCertValidSince),
			TLSClientCertSubject = VALUES(TLSClientCertSubject), TLSClientCertIssuer = VALUES(TLSClientCertIssuer),
			TLSClientCertCommonName = VALUES(TLSClientCertCommonName), TLSClientCertSubjectAltNameEmail = VALUES(TLSClientCertSubjectAltNameEmail),
			TLSClientCertX509v3ExtendedKeyUsage = VALUES(TLSClientCertX509v3ExtendedKeyUsage),
			TLSClientCertX509v3SubjectKeyIdentifier = VALUES(TLSClientCertX509v3SubjectKeyIdentifier),
			TLSClientCertX509v3AuthorityKeyIdentifier = VALUES(TLSClientCertX509v3AuthorityKeyIdentifier),
			TLSClientCertX509v3ExtendedKeyUsageOID = VALUES(TLSClientCertX509v3ExtendedKeyUsageOID)

		`
	return sql, args, true
}

func keyExists(myMap map[string]interface{}, key string) bool {
	_, exists := myMap[key]
	return exists
}

func (j *FlushRadiusAuditLogJob) argsFromEntriesForTLS(entries [][]interface{}) []interface{} {
	args := make([]interface{}, 0, len(entries)*NODE_TLS_COLUMN_COUNT)
	for _, e := range entries {
		if len(e) < 1 {
			continue
		}
		lookup, ok := e[1].(map[string]interface{})
		if !ok {
			continue
		}
		if !keyExists(lookup, "Calling-Station-Id") {
			fmt.Printf("Not found Calling-Station-Id\n")
			continue
		}

		if !keyExists(lookup, "TLS-Client-Cert-Common-Name") {
			fmt.Printf("Not found TLS-Client-Cert-Common-Name\n")
			continue
		}

		args = append(args, j.argsFromEntryForTLS(lookup)...)

	}

	return args
}

func (j *FlushRadiusAuditLogJob) argsFromEntryForTLS(lookup map[string]interface{}) []interface{} {
	args := make([]interface{}, NODE_TLS_COLUMN_COUNT)
	request := parseRequestArgs(lookup)
	args[0] = formatRequestValue(request["Calling-Station-Id"], "")
	args[1] = formatRequestValue(request["TLS-Cert-Serial"], "N/A")
	args[2] = formatRequestValue(request["TLS-Cert-Expiration"], "N/A")
	args[3] = formatRequestValue(request["TLS-Cert-Valid-Since"], "N/A")
	args[4] = formatRequestValue(request["TLS-Cert-Subject"], "N/A")
	args[5] = formatRequestValue(request["TLS-Cert-Issuer"], "N/A")
	args[6] = formatRequestValue(request["TLS-Cert-Common-Name"], "N/A")
	args[7] = formatRequestValue(request["TLS-Cert-Subject-Alt-Name-Email"], "N/A")
	args[8] = formatRequestValue(request["TLS-Client-Cert-Serial"], "N/A")
	args[9] = formatRequestValue(request["TLS-Client-Cert-Expiration"], "N/A")
	args[10] = formatRequestValue(request["TLS-Client-Cert-Valid-Since"], "N/A")
	args[11] = formatRequestValue(request["TLS-Client-Cert-Subject"], "N/A")
	args[12] = formatRequestValue(request["TLS-Client-Cert-Issuer"], "N/A")
	args[13] = formatRequestValue(request["TLS-Client-Cert-Common-Name"], "N/A")
	args[14] = formatRequestValue(request["TLS-Client-Cert-Subject-Alt-Name-Email"], "N/A")
	args[15] = formatRequestValue(request["TLS-Client-Cert-X509v3-Extended-Key-Usage"], "N/A")
	args[16] = formatRequestValue(request["TLS-Client-Cert-X509v3-Subject-Key-Identifier"], "N/A")
	args[17] = formatRequestValue(request["TLS-Client-Cert-X509v3-Authority-Key-Identifier"], "N/A")
	args[18] = formatRequestValue(request["TLS-Client-Cert-X509v3-Extended-Key-Usage-OID"], "N/A")
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

func parseRequestArgs(request map[string]interface{}) map[string]interface{} {
	if val, ok := request["WLAN-AKM-Suite"].(float64); ok {
		request["WLAN-AKM-Suite"] = mapAKMSuite(int(val))
	}
	if val, ok := request["WLAN-Group-Cipher"].(float64); ok {
		request["WLAN-Group-Cipher"] = mapCipherSuite(int(val))
	}
	if val, ok := request["WLAN-Pairwise-Cipher"].(float64); ok {
		request["WLAN-Pairwise-Cipher"] = mapCipherSuite(int(val))
	}
	if val, ok := request["TLS-Cert-Expiration"].(string); ok {
		request["TLS-Cert-Expiration"] = formatDate(val)
	}
	if val, ok := request["TLS-Cert-Valid-Since"].(string); ok {
		request["TLS-Cert-Valid-Since"] = formatDate(val)
	}
	if val, ok := request["TLS-Client-Cert-Expiration"].(string); ok {
		request["TLS-Client-Cert-Expiration"] = formatDate(val)
	}
	if val, ok := request["TLS-Client-Cert-Valid-Since"].(string); ok {
		request["TLS-Client-Cert-Valid-Since"] = formatDate(val)
	}
	return request
}

type AKMSuite int

const (
	AKMReserved         AKMSuite = iota // 0 - Reserved
	IEEE8021X                           // 1 - 802.1X
	PSK                                 // 2 - PSK
	FT_8021X                            // 3 - FT over 802.1X
	FT_PSK                              // 4 - FT over PSK
	WPA_8021X                           // 5 - WPA with 802.1X
	WPA_PSK                             // 6 - WPA with PSK
	OWE                                 // 7 - OWE
	OWE_Transition                      // 8 - OWE Transition Mode
	SAE                                 // 9 - Simultaneous Authentication of Equals
	FT_SAE                              // 10 - FT over SAE
	FILS_SHA256                         // 11 - FILS-SHA256
	FILS_SHA384                         // 12 - FILS-SHA384
	FT_FILS_SHA256                      // 13 - FT over FILS-SHA256
	FT_FILS_SHA384                      // 14 - FT over FILS-SHA384
	OWE_transition_mode                 // 15 - OWE transition mode
)

type CipherSuite int

const (
	CipherReserved   CipherSuite = iota // 0 - Reserved
	WEP40                               // 1 - WEP-40
	TKIP                                // 2 - TKIP
	CipherReserved3                     // 3 - Reserved
	CCMP128                             // 4 - CCMP-128
	WEP104                              // 5 - WEP-104
	BIPCMAC128                          // 6 - BIP-CMAC-128
	GCMP128                             // 7 - GCMP-128
	GCMP256                             // 8 - GCMP-256
	CCMP256                             // 9 - CCMP-256
	BIPGMAC128                          // 10 - BIP-GMAC-128
	BIPGMAC256                          // 11 - BIP-GMAC-256
	SMS4                                // 12 - SMS4
	CKIP128                             // 13 - CKIP-128
	CKIP128_PMK                         // 14 - CKIP-128 with PMK caching
	CipherReserved15                    // 15 - Reserved
)

func (c CipherSuite) String() string {
	switch c {
	case WEP40:
		return "WEP-40"
	case TKIP:
		return "TKIP"
	case CCMP128:
		return "CCMP-128"
	case WEP104:
		return "WEP-104"
	case GCMP128:
		return "GCMP-128"
	case GCMP256:
		return "GCMP-256"
	case CCMP256:
		return "CCMP-256"
	case BIPCMAC128:
		return "BIP-CMAC-128"
	case BIPGMAC128:
		return "BIP-GMAC-128"
	case BIPGMAC256:
		return "BIP-GMAC-256"
	case SMS4:
		return "SMS4"
	case CKIP128:
		return "CKIP-128"
	case CKIP128_PMK:
		return "CKIP-128 with PMK caching"
	case CipherReserved3, CipherReserved15:
		return "Reserved"
	default:
		return fmt.Sprintf("Unknown cipher suite (Value: %d)", c)
	}
}

func (a AKMSuite) String() string {
	switch a {
	case IEEE8021X:
		return "802.1X"
	case PSK:
		return "PSK"
	case FT_8021X:
		return "FT over 802.1X"
	case FT_PSK:
		return "FT over PSK"
	case WPA_8021X:
		return "WPA with 802.1X"
	case WPA_PSK:
		return "WPA with PSK"
	case OWE:
		return "OWE"
	case OWE_Transition:
		return "OWE Transition Mode"
	case SAE:
		return "SAE"
	case FT_SAE:
		return "FT over SAE"
	case FILS_SHA256:
		return "FILS-SHA256"
	case FILS_SHA384:
		return "FILS-SHA384"
	case FT_FILS_SHA256:
		return "FT over FILS-SHA256"
	case FT_FILS_SHA384:
		return "FT over FILS-SHA384"
	case OWE_transition_mode:
		return "OWE transition mode"
	default:
		return fmt.Sprintf("Unknown or Reserved AKM suite (Value: %d)", a)
	}
}

func mapAKMSuite(akmSuiteInt int) string {
	akmSuiteSelector := akmSuiteInt & 0x0000000F
	return AKMSuite(akmSuiteSelector).String()
}

func mapCipherSuite(cipherSuiteInt int) string {
	cipherSuiteSelector := cipherSuiteInt & 0x0000000F
	return CipherSuite(cipherSuiteSelector).String()
}

func formatDate(dateStr string) string {
	const dateFormat2Digit = "060102150405Z"
	const dateFormat4Digit = "20060102150405Z"

	var t time.Time
	var err error
	t, err = time.Parse(dateFormat2Digit, dateStr)
	if err != nil {
		t, err = time.Parse(dateFormat4Digit, dateStr)
		if err != nil {
			return dateStr // Return the original string if parsing fails
		}
	}

	return t.Format("2006-01-02 03:04:05 PM UTC")
}
