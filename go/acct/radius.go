package main

import (
	"context"
	"database/sql"
	"encoding/binary"
	"fmt"
	"hash"
	"net"
	"sync"
	"time"

	"github.com/OneOfOne/xxhash"
	cache "github.com/fdurand/go-cache"

	"github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/dictionary"
	"github.com/inverse-inc/go-radius/rfc2865"
	"github.com/inverse-inc/go-radius/rfc2866"
	"github.com/inverse-inc/go-radius/rfc2869"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/mac"
)

const TRIGGER_TYPE_ACCOUNTING = "accounting"
const ACCOUNTING_POLICY_BANDWIDTH = "BandwidthExpired"
const ACCOUNTING_POLICY_TIME = "TimeExpired"

var radiusDictionary *dictionary.Dictionary

func (h *PfAcct) AddProxyState(packet *radius.Packet, r *radius.Request) *radius.Packet {
	state, err := rfc2865.ProxyState_Lookup(r.Packet)
	if err == nil {
		rfc2865.ProxyState_Add(packet, state)
	}
	return packet
}

func (h *PfAcct) ServeRADIUS(w radius.ResponseWriter, r *radius.Request) {
	switch r.Code {
	case radius.CodeAccountingRequest:
		h.HandleAccounting(w, r)
	case radius.CodeStatusServer:
		h.HandleStatusServer(w, r)
	}
}

func (h *PfAcct) hasher() hash.Hash64 {
	return xxhash.New64()
}

func (h *PfAcct) HandleStatusServer(w radius.ResponseWriter, r *radius.Request) {
	w.Write(h.AddProxyState(r.Response(radius.CodeAccessAccept), r))
}

func (h *PfAcct) HandleAccounting(w radius.ResponseWriter, r *radius.Request) {
	defer h.NewTiming().Send("pfacct.HandleAccountingRequest")
	outPacket := r.Response(radius.CodeAccountingResponse)
	rfc2865.ReplyMessage_SetString(outPacket, "Accounting OK")
	ctx := r.Context()
	iSwitchInfo := ctx.Value(switchInfoKey)
	if iSwitchInfo == nil {
		panic("SwitchInfo: not found")
	}

	switchInfo := iSwitchInfo.(*SwitchInfo)
	h.handleAccountingRequest(r, switchInfo)
	//	h.Dispatcher.SubmitJob(Work(func() { h.handleAccountingRequest(r, switchInfo) }))
	w.Write(h.AddProxyState(outPacket, r))
}

func (h *PfAcct) handleAccountingRequest(r *radius.Request, switchInfo *SwitchInfo) {
	ctx := r.Context()
	status := rfc2866.AcctStatusType_Get(r.Packet)
	defer h.NewTiming().Send("pfacct.accounting." + status.String())
	if status > rfc2866.AcctStatusType_Value_InterimUpdate {
		logInfo(ctx, fmt.Sprintf("Accounting status of %s ignored", status.String()))
		return
	}

	callingStation := rfc2865.CallingStationID_GetString(r.Packet)
	mac, _ := mac.NewFromString(callingStation)
	in_bytes := int64(rfc2866.AcctInputOctets_Get(r.Packet))
	out_bytes := int64(rfc2866.AcctOutputOctets_Get(r.Packet))
	giga_in_bytes := int64(rfc2869.AcctInputGigawords_Get(r.Packet))
	giga_out_bytes := int64(rfc2869.AcctOutputGigawords_Get(r.Packet))
	out_bytes += giga_out_bytes << 32
	in_bytes += giga_in_bytes << 32
	timestamp := rfc2869.EventTimestamp_Get(r.Packet)
	if timestamp.IsZero() {
		timestamp = time.Now()
	}
	timestamp = timestamp.Truncate(h.TimeDuration)
	node_id := mac.NodeId(uint16(switchInfo.TenantId))
	unique_session_id := h.accountingUniqueSessionId(r)
	err := h.InsertBandwidthAccounting(
		node_id,
		switchInfo.TenantId,
		mac.String(),
		unique_session_id,
		timestamp,
		in_bytes,
		out_bytes,
	)
	if err != nil {
		logError(ctx, "InsertBandwidthAccounting: "+err.Error())
	}

	if status == rfc2866.AcctStatusType_Value_Stop {
		h.CloseSession(node_id, unique_session_id)
	}

	h.sendRadiusAccounting(r)
	h.handleTimeBalance(r, switchInfo)
	h.handleBandwidthBalance(r, switchInfo, in_bytes+out_bytes)
}

func (h *PfAcct) handleTimeBalance(r *radius.Request, switchInfo *SwitchInfo) {
	timebalance := int64(rfc2866.AcctSessionTime_Get(r.Packet))
	if timebalance == 0 {
		return
	}
	ctx := r.Context()

	callingStation := rfc2865.CallingStationID_GetString(r.Packet)
	mac, _ := mac.NewFromString(callingStation)
	status := rfc2866.AcctStatusType_Get(r.Packet)
	if status == rfc2866.AcctStatusType_Value_Stop {
		ok, err := h.NodeTimeBalanceSubtract(switchInfo.TenantId, mac, timebalance)
		if err != nil {
			logError(ctx, "NodeTimeBalanceSubtract: "+err.Error())
			return
		}
		if ok {
			if ok, err = h.IsNodeTimeBalanceZero(switchInfo.TenantId, mac); ok {
				if err := h.AAAClient.Notify(ctx, "trigger_security_event", []interface{}{"type", TRIGGER_TYPE_ACCOUNTING, "mac", mac.String(), "tid", ACCOUNTING_POLICY_TIME}, switchInfo.TenantId); err != nil {
					logError(ctx, "IsNodeTimeBalanceZero: "+err.Error())
				}
			}
		}
	} else {
		ok, err := h.SoftNodeTimeBalanceUpdate(switchInfo.TenantId, mac, timebalance)
		if err != nil {
			logError(ctx, "SoftNodeTimeBalanceUpdate: "+err.Error())
			return
		}
		if ok {
			if err := h.AAAClient.Notify(ctx, "trigger_security_event", []interface{}{"type", TRIGGER_TYPE_ACCOUNTING, "mac", mac.String(), "tid", ACCOUNTING_POLICY_TIME}, switchInfo.TenantId); err != nil {
				logError(ctx, "Notify trigger_security_event: "+err.Error())
			}
		}
	}
}

func (h *PfAcct) handleBandwidthBalance(r *radius.Request, switchInfo *SwitchInfo, balance int64) {
	if balance == 0 {
		return
	}

	ctx := r.Context()
	callingStation := rfc2865.CallingStationID_GetString(r.Packet)
	mac, _ := mac.NewFromString(callingStation)
	status := rfc2866.AcctStatusType_Get(r.Packet)
	if status == rfc2866.AcctStatusType_Value_Stop {
		ok, err := h.NodeBandwidthBalanceSubtract(switchInfo.TenantId, mac, balance)
		if err != nil {
			logError(ctx, "NodeBandwidthBalanceSubtract: "+err.Error())
			return
		}
		if ok {
			if ok, err = h.IsNodeBandwidthBalanceZero(switchInfo.TenantId, mac); ok {
				if err := h.AAAClient.Notify(ctx, "trigger_security_event", []interface{}{"type", TRIGGER_TYPE_ACCOUNTING, "mac", mac.String(), "tid", ACCOUNTING_POLICY_BANDWIDTH}, switchInfo.TenantId); err != nil {
					logError(ctx, "IsNodeBandwidthBalanceZero: "+err.Error())
				}
			}
		}
	} else {
		ok, err := h.SoftNodeBandwidthBalanceUpdate(switchInfo.TenantId, mac, balance)
		if err != nil {
			logError(ctx, "SoftNodeBandwidthBalanceUpdate: "+err.Error())
			return
		}
		if ok {
			if err := h.AAAClient.Notify(ctx, "trigger_security_event", []interface{}{"type", TRIGGER_TYPE_ACCOUNTING, "mac", mac.String(), "tid", ACCOUNTING_POLICY_BANDWIDTH}, switchInfo.TenantId); err != nil {
				logError(ctx, "Notify trigger_security_event: "+err.Error())
			}
		}
	}
}

func (h *PfAcct) accountingUniqueSessionId(r *radius.Request) uint64 {
	username := rfc2865.UserName_Get(r.Packet)
	callingStation := rfc2865.CallingStationID_Get(r.Packet)
	acctSessionId := rfc2866.AcctSessionID_Get(r.Packet)
	hash := h.hasher()
	hash.Write(username)
	hash.Write([]byte{','})
	hash.Write(callingStation)
	hash.Write([]byte{','})
	hash.Write(acctSessionId)
	return hash.Sum64()
}

func (h *PfAcct) sendRadiusAccounting(r *radius.Request) {
	ctx := r.Context()
	attr := packetToMap(ctx, r.Packet)
	attr["PF_HEADERS"] = map[string]string{
		"X-FreeRADIUS-Server":  "packetfence",
		"X-FreeRADIUS-Section": "accounting",
	}

	if _, err := h.AAAClient.Call(ctx, "radius_accounting", attr, 1); err != nil {
		logError(ctx, err.Error())
	}
}

func (h *PfAcct) radiusListen(w *sync.WaitGroup) *radius.PacketServer {
	var connStr string
	if h.Management.Vip != "" {
		connStr = h.Management.Vip + ":1813"
	} else {
		connStr = h.Management.Ip + ":1813"
	}

	addr, err := net.ResolveUDPAddr("udp", connStr)
	if err != nil {
		panic(err)
	}

	pc, err := net.ListenUDP("udp", addr)
	if err != nil {
		panic(err)
	}

	server := &radius.PacketServer{
		Handler:      h,
		SecretSource: h,
	}
	w.Add(1)
	go func() {
		if err := server.Serve(pc); err != radius.ErrServerShutdown {
			panic(err)
		}

		w.Done()
	}()

	return server
}

type contextKey int

const (
	switchInfoKey contextKey = iota
)

func (h *PfAcct) RADIUSSecret(ctx context.Context, remoteAddr net.Addr, raw []byte) ([]byte, context.Context, error) {
	ip := remoteAddr.(*net.UDPAddr).IP.String()
	var err error
	var macStr string
	err = checkPacket(raw)
	if err != nil {
		logError(h.LoggerCtx, "RADIUSSecret: "+err.Error())
		return nil, nil, err
	}

	attrs, err := radius.ParseAttributes(raw[20:])
	if err != nil {
		logError(h.LoggerCtx, "RADIUSSecret: "+err.Error())
		return nil, nil, err
	}

	attr, ok := attrs.Lookup(rfc2865.CalledStationID_Type)
	if !ok {
		macStr = ""
	} else {
		mac, err := mac.NewFromString(string(attr))
		if err != nil {
			macStr = ""
		} else {
			macStr = mac.String()
		}
	}

	switchInfo, err := h.SwitchLookup(macStr, ip)
	if err != nil {
		logError(h.LoggerCtx, "RADIUSSecret: Switch '"+ip+"' not found :"+err.Error())
		return nil, nil, err
	}

	return []byte(switchInfo.Secret), log.TranferLogContext(h.LoggerCtx, context.WithValue(ctx, switchInfoKey, switchInfo)), nil
}

type Error string

func (e Error) Error() string { return string(e) }

const PacketTooSmall = Error("radius: packet not at least 20 bytes long")
const PacketInvalidLength = Error("radius: invalid packet length")

func checkPacket(raw []byte) error {
	if len(raw) < 20 {
		return PacketTooSmall
	}

	length := int(binary.BigEndian.Uint16(raw[2:4]))
	if length < 20 || length > radius.MaxPacketLength || len(raw) != length {
		return PacketInvalidLength
	}

	return nil
}

func packetToMap(ctx context.Context, p *radius.Packet) map[string]interface{} {

	attributes := make(map[string]interface{})
	for i, attr := range p.Attributes {
		if rfc2865.VendorSpecific_Type == i {
			for _, vattrs := range attr {
				id, vsa, err := radius.VendorSpecific(vattrs)
				if err != nil {
					log.LoggerWContext(ctx).Error(fmt.Sprintf("Unknown vendor id: %d", id))
					continue
				}

				v := radiusDictionary.GetVendorByNumber(uint(id))
				if v == nil {
					log.LoggerWContext(ctx).Error(fmt.Sprintf("Unknown vendor id: %d", id))
					continue
				}

				for len(vsa) >= 3 {
					vsaTyp, vsaLen := vsa[0], vsa[1]
					data := vsa[2:int(vsaLen)]
					a := dictionary.AttributeByOID(v.Attributes, []int{int(vsaTyp)})
					vsa = vsa[int(vsaLen):]
					if a == nil {
						continue
					}

					addAttributeToMap(ctx, attributes, a, radius.Attribute(data))
				}
			}
		} else {
			a := radiusDictionary.GetAttributeByOID([]int{int(i)})
			if a == nil {
				log.LoggerWContext(ctx).Error(fmt.Sprintf("Unknown Attribute: %d", int(i)))
				continue
			}

			addAttributeToMap(ctx, attributes, a, attr[0])
		}
	}

	if val, found := attributes["Calling-Station-Id"]; found {
		if mac, err := mac.NewFromString(val.(string)); err == nil {
			attributes["Calling-Station-Id"] = mac.String()
		}
	}

	return attributes
}

func addAttributeToMap(ctx context.Context, attributes map[string]interface{}, da *dictionary.Attribute, attr radius.Attribute) {
	var item interface{} = nil
	switch da.Type {
	case dictionary.AttributeString:
		item = radius.String(attr)
	case dictionary.AttributeInteger:
		i, err := radius.Integer(attr)
		if err == nil {
			item = i
		}
	case dictionary.AttributeInteger64:
		i, err := radius.Integer64(attr)
		if err == nil {
			item = i
		}
	case dictionary.AttributeIPAddr:
		i, err := radius.IPAddr(attr)
		if err == nil {
			item = i.String()
		}
	case dictionary.AttributeDate:
		i, err := radius.Date(attr)
		if err == nil {
			item = i.String()
		}
	}

	if item != nil {
		if old, found := attributes[da.Name]; found {
			switch old.(type) {
			case []interface{}:
				attributes[da.Name] = append(old.([]interface{}), item)
			default:
				attributes[da.Name] = []interface{}{old, item}
			}
		} else {
			attributes[da.Name] = item
		}
	} else {
		logDebug(ctx, fmt.Sprintf("Serialization of data type %s for %s not handled\n", da.Type, da.Name))
	}
}

func logError(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Error(msg)
}

func logWarn(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Warn(msg)
}

func logInfo(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Info(msg)
}

func logDebug(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Debug(msg)
}

type RadiusStatements struct {
	switchLookup                   *sql.Stmt
	insertBandwidthAccounting      *sql.Stmt
	softNodeTimeBalanceUpdate      *sql.Stmt
	nodeTimeBalanceSubtract        *sql.Stmt
	nodeTimeBalance                *sql.Stmt
	isNodeTimeBalanceZero          *sql.Stmt
	softNodeBandwidthBalanceUpdate *sql.Stmt
	nodeBandwidthBalanceSubtract   *sql.Stmt
	nodeBandwidthBalance           *sql.Stmt
	isNodeBandwidthBalanceZero     *sql.Stmt
	closeSession                   *sql.Stmt
}

func (rs *RadiusStatements) Setup(db *sql.DB) {
	var err error
	rs.switchLookup, err = db.Prepare(`
        SELECT nasname, secret, tenant_id, unique_session_attributes FROM radius_nas WHERE nasname = ?
        UNION
          SELECT nasname, secret, tenant_id, unique_session_attributes FROM radius_nas WHERE nasname = ?
        UNION
        (
            SELECT nasname, secret, tenant_id, unique_session_attributes from radius_nas
            WHERE INET_ATON(?) BETWEEN start_ip AND end_ip
            ORDER BY range_length LIMIT 1
        ) LIMIT 1;
    `)

	if err != nil {
		panic(err)
	}

	rs.insertBandwidthAccounting, err = db.Prepare(`
        INSERT INTO bandwidth_accounting (node_id, tenant_id, mac, unique_session_id, time_bucket, in_bytes, out_bytes, source_type)
            SELECT ? as node_id, ? AS tenant_id, ? AS mac, ? AS unique_session_id, ? AS time_bucket, in_bytes, out_bytes, "radius" FROM (
                SELECT GREATEST(? - IFNULL(SUM(in_bytes), 0), 0) AS in_bytes, GREATEST(? - IFNULL(SUM(out_bytes), 0), 0) AS out_bytes FROM bandwidth_accounting WHERE node_id = ? AND unique_session_id = ? AND time_bucket != ?
            ) AS y
        ON DUPLICATE KEY UPDATE in_bytes = VALUES(in_bytes), out_bytes = VALUES(out_bytes), last_updated = NOW();
    `)

	if err != nil {
		panic(err)
	}

	rs.softNodeTimeBalanceUpdate, err = db.Prepare(`
        UPDATE node set time_balance = 0 WHERE tenant_id = ? AND mac = ? AND time_balance - ? <= 0;
    `)

	if err != nil {
		panic(err)
	}

	rs.softNodeBandwidthBalanceUpdate, err = db.Prepare(`
        UPDATE node set bandwidth_balance = 0 WHERE tenant_id = ? AND mac = ? AND bandwidth_balance - ? <= 0;
    `)

	if err != nil {
		panic(err)
	}

	rs.nodeTimeBalanceSubtract, err = db.Prepare(`
        UPDATE node set time_balance = GREATEST(time_balance - ?, 0) WHERE tenant_id = ? AND mac = ? AND time_balance IS NOT NULL;
    `)

	if err != nil {
		panic(err)
	}

	rs.nodeBandwidthBalanceSubtract, err = db.Prepare(`
        UPDATE node set bandwidth_balance = GREATEST(bandwidth_balance - ?, 0) WHERE tenant_id = ? AND mac = ? AND bandwidth_balance IS NOT NULL;
    `)

	if err != nil {
		panic(err)
	}

	rs.nodeTimeBalance, err = db.Prepare(`
        SELECT time_balance FROM node WHERE tenant_id = ? AND mac = ? AND time_balance IS NOT NULL;
    `)

	if err != nil {
		panic(err)
	}

	rs.nodeBandwidthBalance, err = db.Prepare(`
        SELECT bandwidth_balance FROM node WHERE tenant_id = ? AND mac = ? AND bandwidth_balance IS NOT NULL;
    `)

	if err != nil {
		panic(err)
	}

	rs.isNodeTimeBalanceZero, err = db.Prepare(`
        SELECT 1 FROM node WHERE tenant_id = ? AND mac = ? AND time_balance = 0;
    `)

	if err != nil {
		panic(err)
	}

	rs.isNodeBandwidthBalanceZero, err = db.Prepare(`
        SELECT 1 FROM node WHERE tenant_id = ? AND mac = ? AND bandwidth_balance = 0;
    `)

	if err != nil {
		panic(err)
	}

	rs.closeSession, err = db.Prepare(`
        UPDATE bandwidth_accounting SET last_updated = '0000-00-00 00:00:00' WHERE node_id = ? AND unique_session_id = ?;
    `)

	if err != nil {
		panic(err)
	}
}

func (rs *RadiusStatements) CloseSession(node_id, unique_session_id uint64) (int64, error) {
	result, err := rs.closeSession.Exec(node_id, unique_session_id)
	if err != nil {
		return 0, err
	}

	return result.RowsAffected()
}

func (rs *RadiusStatements) IsNodeTimeBalanceZero(tenant_id int, mac mac.Mac) (bool, error) {
	found := 0
	err := rs.isNodeTimeBalanceZero.QueryRow(tenant_id, mac).Scan(&found)
	return found == 1, err
}

func (rs *RadiusStatements) SoftNodeTimeBalanceUpdate(tenant_id int, mac mac.Mac, balance int64) (bool, error) {
	result, err := rs.softNodeTimeBalanceUpdate.Exec(tenant_id, mac.String(), balance)
	if err != nil {
		return false, err
	}

	if count, err := result.RowsAffected(); count <= 0 || err != nil {
		return false, err
	}

	return true, nil
}

func (rs *RadiusStatements) NodeTimeBalanceSubtract(tenant_id int, mac mac.Mac, balance int64) (bool, error) {
	result, err := rs.nodeTimeBalanceSubtract.Exec(balance, tenant_id, mac.String())
	if err != nil {
		return false, err
	}

	if count, err := result.RowsAffected(); count <= 0 || err != nil {
		return false, err
	}

	return true, nil
}

func (rs *RadiusStatements) IsNodeBandwidthBalanceZero(tenant_id int, mac mac.Mac) (bool, error) {
	found := 0
	err := rs.isNodeBandwidthBalanceZero.QueryRow(tenant_id, mac).Scan(&found)
	return found == 1, err
}

func (rs *RadiusStatements) SoftNodeBandwidthBalanceUpdate(tenant_id int, mac mac.Mac, balance int64) (bool, error) {
	result, err := rs.softNodeBandwidthBalanceUpdate.Exec(tenant_id, mac.String(), balance)
	if err != nil {
		return false, err
	}

	if count, err := result.RowsAffected(); count <= 0 || err != nil {
		return false, err
	}

	return true, nil
}

func (rs *RadiusStatements) NodeBandwidthBalanceSubtract(tenant_id int, mac mac.Mac, balance int64) (bool, error) {
	result, err := rs.nodeBandwidthBalanceSubtract.Exec(balance, tenant_id, mac.String())
	if err != nil {
		return false, err
	}

	if count, err := result.RowsAffected(); count <= 0 || err != nil {
		return false, err
	}

	return true, nil
}

type SwitchInfo struct {
	Nasname, Secret  string
	TenantId         int
	RadiusAttributes db.CsvArray
}

func (h *PfAcct) SwitchLookup(mac, ip string) (*SwitchInfo, error) {
	key := mac + ":" + ip
	if item, found := h.SwitchInfoCache.Get(key); found {
		return item.(*SwitchInfo), nil
	}

	switchInfo := &SwitchInfo{}
	err := h.switchLookup.QueryRow(mac, ip, ip).Scan(&switchInfo.Nasname, &switchInfo.Secret, &switchInfo.TenantId, &switchInfo.RadiusAttributes)
	if err != nil {
		return nil, err
	}

	h.SwitchInfoCache.Set(key, switchInfo, cache.DefaultExpiration)
	return switchInfo, nil
}

func (rs *RadiusStatements) InsertBandwidthAccounting(node_id uint64, tenant_id int, mac string, unique_session uint64, bucket time.Time, in_bytes int64, out_bytes int64) error {
	_, err := rs.insertBandwidthAccounting.Exec(
		node_id,
		tenant_id,
		mac,
		unique_session,
		bucket,
		in_bytes,
		out_bytes,
		node_id,
		unique_session,
		bucket,
	)
	return err
}

func init() {
	parser := &dictionary.Parser{
		Opener: &dictionary.FileSystemOpener{
			Root: "/usr/share/freeradius",
		},
		IgnoreIdenticalAttributes:  true,
		IgnoreUnknownAttributeType: true,
	}

	var err error
	if radiusDictionary, err = parser.ParseFile("dictionary"); err != nil {
		panic(err)
	}
}
