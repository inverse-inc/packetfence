package main

import (
	"context"
	"crypto/md5"
	"database/sql"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/inverse-inc/go-radius/dictionary"
	"github.com/inverse-inc/go-radius/rfc2865"
	"github.com/inverse-inc/go-radius/rfc2866"
	"github.com/inverse-inc/go-radius/rfc2869"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/mac"
)

var radiusDictionary *dictionary.Dictionary

func (h *PfAcct) ServeRADIUS(w radius.ResponseWriter, r *radius.Request) {
	if r.Code == radius.CodeAccountingRequest {
		h.HandleAccountingRequest(w, r)
		return
	}
}

func (h *PfAcct) HandleAccountingRequest(w radius.ResponseWriter, r *radius.Request) {
	outPacket := r.Response(radius.CodeAccountingResponse)
	rfc2865.ReplyMessage_SetString(outPacket, "Accounting ok")
	w.Write(outPacket)
	ctx := r.Context()
	iSwitchInfo := ctx.Value(switchInfoKey)
	if iSwitchInfo == nil {
		panic("SwitchInfo: not found")
	}
	switchInfo := iSwitchInfo.(*SwitchInfo)
	h.handleAccountingRequest(r, switchInfo)
}

func (h *PfAcct) handleAccountingRequest(r *radius.Request, switchInfo *SwitchInfo) {
	//Acct-Output-Gigawords

	callingStation := rfc2865.CallingStationID_GetString(r.Packet)
	mac, _ := mac.NewFromString(callingStation)
	in_bytes := int64(rfc2866.AcctInputOctets_Get(r.Packet))
	out_bytes := int64(rfc2866.AcctOutputOctets_Get(r.Packet))
	giga_in_bytes := int64(rfc2869.AcctInputGigawords_Get(r.Packet))
	giga_out_bytes := int64(rfc2869.AcctOutputGigawords_Get(r.Packet))
	out_bytes += giga_out_bytes << 32
	in_bytes += giga_in_bytes << 32
	timestamp := rfc2869.EventTimestamp_Get(r.Packet)
	timestamp = timestamp.Truncate(h.TimeDuration)
	h.InsertBandwidthAccounting(
		switchInfo.TenantId,
		mac.String(),
		h.accountingUniqueSessionId(r),
		timestamp,
		in_bytes,
		out_bytes,
	)
	h.sendRadiusAccounting(r)
}

func (h *PfAcct) accountingUniqueSessionId(r *radius.Request) string {
	username := rfc2865.UserName_Get(r.Packet)
	callingStation := rfc2865.CallingStationID_Get(r.Packet)
	acctSessionId := rfc2866.AcctSessionID_Get(r.Packet)
	hash := md5.New()
	hash.Write(username)
	hash.Write([]byte{','})
	hash.Write(callingStation)
	hash.Write([]byte{','})
	hash.Write(acctSessionId)
	sum := hash.Sum(nil)
	return hex.EncodeToString(sum)
}

func (h *PfAcct) sendRadiusAccounting(r *radius.Request) {
	attr := packetToMap(r.Context(), r.Packet)
	attr["PF_HEADERS"] = map[string]string{
		"X-FreeRADIUS-Server":  "packetfence",
		"X-FreeRADIUS-Section": "accounting",
	}
	client := jsonrpc2.NewAAAClientFromConfig(r.Context())
	if _, err := client.Call("radius_accounting", attr, 1); err != nil {
		log.LoggerWContext(r.Context()).Error(err.Error())
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
		return nil, nil, err
	}

	attrs, err := radius.ParseAttributes(raw[20:])
	if err != nil {
		return nil, nil, err
	}

	attr, ok := attrs.Lookup(rfc2865.CalledStationID_Type)
	if !ok {
		macStr = ""
	} else {
		mac, err := mac.NewFromString(string(attr[0:17]))
		if err != nil {
			macStr = ""
		} else {
			macStr = mac.String()
		}
	}

	switchInfo, err := h.SwitchLookup(macStr, ip)
	if err != nil {
		return nil, nil, err
	}

	return []byte(switchInfo.Secret), context.WithValue(ctx, switchInfoKey, switchInfo), nil
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

				v := dictionary.VendorByNumber(radiusDictionary.Vendors, uint(id))
				if v == nil {
					log.LoggerWContext(ctx).Error(fmt.Sprintf("Unknown vendor id: %d", id))
					continue
				}

				for len(vsa) >= 3 {
					vsaTyp, vsaLen := vsa[0], vsa[1]
					data := vsa[2:int(vsaLen)]
					a := dictionary.AttributeByOID(v.Attributes, []int{int(vsaTyp)})
					if a == nil {
						continue
					}

					addAttributeToMap(attributes, a, radius.Attribute(data))
					vsa = vsa[int(vsaLen):]
				}
			}
		} else {
			a := dictionary.AttributeByOID(radiusDictionary.Attributes, []int{int(i)})
			if a == nil {
				log.LoggerWContext(ctx).Error(fmt.Sprintf("Unknown Attribute: %d", int(i)))
				continue
			}
			addAttributeToMap(attributes, a, attr[0])
		}
	}

	return attributes
}

func addAttributeToMap(attributes map[string]interface{}, da *dictionary.Attribute, attr radius.Attribute) {
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
	}
}

type RadiusStatements struct {
	switchLookup, insertBandwidthAccounting *sql.Stmt
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
        INSERT INTO bandwidth_accounting (tenant_id, mac, unique_session_id, time_bucket, in_bytes, out_bytes)
        SELECT ? as tenant_id, ? as mac, ? as unique_session_id, ? as time_bucket, in_bytes, out_bytes FROM (
            SELECT 100 - IFNULL(SUM(in_bytes), 0) as in_bytes, 1000 - IFNULL(SUM(out_bytes), 0) as out_bytes FROM bandwidth_accounting WHERE tenant_id = ? AND unique_session_id = ? AND time_bucket = ?
        ) as x
        ON DUPLICATE KEY UPDATE in_bytes = VALUES(in_bytes), out_bytes = VALUES(out_bytes);
    `)

	if err != nil {
		panic(err)
	}
}

type SwitchInfo struct {
	Nasname, Secret  string
	TenantId         int
	RadiusAttributes db.CsvArray
}

func (rs *RadiusStatements) SwitchLookup(mac, ip string) (*SwitchInfo, error) {
	switchInfo := &SwitchInfo{}
	err := rs.switchLookup.QueryRow(mac, ip, ip).Scan(&switchInfo.Nasname, &switchInfo.Secret, &switchInfo.TenantId, &switchInfo.RadiusAttributes)
	if err != nil {
		return nil, err
	}

	return switchInfo, nil
}

func (rs *RadiusStatements) InsertBandwidthAccounting(tenant_id int, mac string, unique_session string, bucket time.Time, in_bytes int64, out_bytes int64) error {
	_, err := rs.insertBandwidthAccounting.Exec(tenant_id, mac, unique_session, bucket, in_bytes, out_bytes, tenant_id, unique_session, bucket)
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
