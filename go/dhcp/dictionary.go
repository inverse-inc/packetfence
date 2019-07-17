package main

import (
	"encoding/binary"
	"encoding/hex"
	"net"
	"strconv"
	"strings"
)

// TlvList struct
type TlvList struct {
	Tlvlist map[int]TlvType
}

// TlvType struct
type TlvType struct {
	Option    string
	Transform DataType
}

// DataType struct
type DataType interface {
	Value(a []byte) interface{}
	String(a []byte) string
	Encode(a string) []byte
}

var tlvIPAddr tlvIPAddrt

type tlvIPAddrt struct{}

func (s tlvIPAddrt) Value(a []byte) interface{} {
	return a
}
func (s tlvIPAddrt) String(a []byte) string {
	var IPS string
	var temp []byte
	var i int
	var j int
	i = 0
	j = 0
	temp = make([]byte, 4)
	for _, x := range a {
		temp[i] = x
		i++
		if i == 4 {
			var IP net.IP
			IP = temp
			if j == 0 {
				IPS = IP.String()
				j++
			} else {
				IPS = IPS + "," + IP.String()
			}
			i = 0
		}
	}
	return IPS
}

func (s tlvIPAddrt) Encode(a string) []byte {
	var array []net.IP
	slice := make([]byte, 0, len(array))
	for _, adresse := range strings.Split(a, ",") {
		elem := []byte(net.ParseIP(adresse).To4())
		slice = append(slice, elem...)
	}
	return slice
}

var tlvNstring tlvNstringt

type tlvNstringt struct{}

func (s tlvNstringt) Value(a []byte) interface{} {
	return a
}
func (s tlvNstringt) String(a []byte) string {
	return string(a)
}

func (s tlvNstringt) Encode(a string) []byte {
	return []byte(a)
}

var tlvBlob tlvBlobt

type tlvBlobt struct{}

func (s tlvBlobt) Value(a []byte) interface{} {
	return a
}
func (s tlvBlobt) String(a []byte) string {
	return hex.EncodeToString(a)
}

func (s tlvBlobt) Encode(a string) []byte {
	return []byte(a)
}

var tlvSTime tlvSTimet

type tlvSTimet struct{}

func (s tlvSTimet) Value(a []byte) interface{} {
	return a
}
func (s tlvSTimet) String(a []byte) string {
	return string(a)
}
func (s tlvSTimet) Encode(a string) []byte {
	i, _ := strconv.Atoi(a)
	bs := make([]byte, 4)
	binary.BigEndian.PutUint32(bs, uint32(i))
	return bs
}

var tlvZeroSize tlvZeroSizet

type tlvZeroSizet struct{}

func (s tlvZeroSizet) Value(a []byte) interface{} {
	return a
}
func (s tlvZeroSizet) String(a []byte) string {
	return "string"
}
func (s tlvZeroSizet) Encode(a string) []byte {
	return []byte(a)
}

var tlvShort tlvShortt

type tlvShortt struct{}

func (s tlvShortt) Value(a []byte) interface{} {
	return a
}
func (s tlvShortt) String(a []byte) string {
	return strconv.Itoa(int(binary.BigEndian.Uint16(a)))
}
func (s tlvShortt) Encode(a string) []byte {
	return []byte(a)
}

var tlvBool tlvBoolt

type tlvBoolt struct{}

func (s tlvBoolt) Value(a []byte) interface{} {
	switch a[0] {
	case 1:
		return true
	default:
		return false
	}
}
func (s tlvBoolt) String(a []byte) string {
	switch a[0] {
	case 1:
		return "1"
	default:
		return "0"
	}
}
func (s tlvBoolt) Encode(a string) []byte {
	switch a[0] {
	case 1:
		return []byte{1}
	default:
		return []byte{0}
	}
}

var tlvRangeShort tlvRangeShortt

type tlvRangeShortt struct{}

func (s tlvRangeShortt) Value(a []byte) interface{} {
	return a
}
func (s tlvRangeShortt) String(a []byte) string {
	return "string"
}
func (s tlvRangeShortt) Encode(a string) []byte {
	return []byte(a)
}

var tlvOverload tlvOverloadt

type tlvOverloadt struct{}

func (s tlvOverloadt) Value(a []byte) interface{} {
	return a
}
func (s tlvOverloadt) String(a []byte) string {
	return "string"
}
func (s tlvOverloadt) Encode(a string) []byte {
	return []byte(a)
}

var tlvMessage tlvMessaget

type tlvMessaget struct{}

func (s tlvMessaget) Value(a []byte) interface{} {
	return a
}
func (s tlvMessaget) String(a []byte) string {
	return strconv.Itoa(int(a[0]))
}
func (s tlvMessaget) Encode(a string) []byte {
	return []byte(a)
}

var tlvInt8 tlvInt8t

type tlvInt8t struct{}

func (s tlvInt8t) Value(a []byte) interface{} {
	return a
}
func (s tlvInt8t) String(a []byte) string {
	return hex.EncodeToString(a)
}
func (s tlvInt8t) Encode(a string) []byte {
	return []byte(a)
}

// TlvTypeCn var
var TlvTypeCn TlvTypeCnt

// TlvTypeCnt var
type TlvTypeCnt struct{}

// Value function
func (s TlvTypeCnt) Value(a []byte) interface{} {
	return a
}

// String function
func (s TlvTypeCnt) String(a []byte) string {
	return "string"
}

// Encode function
func (s TlvTypeCnt) Encode(a string) []byte {
	return []byte(a)
}

var tlvRangeByte tlvRangeBytet

type tlvRangeBytet struct{}

func (s tlvRangeBytet) Value(a []byte) interface{} {
	return a
}
func (s tlvRangeBytet) String(a []byte) string {
	return "string"
}
func (s tlvRangeBytet) Encode(a string) []byte {
	return []byte(a)
}

var extractFingerPrint extractFingerPrintt

type extractFingerPrintt struct{}

func (s extractFingerPrintt) Value(a []byte) interface{} {
	return a
}

func (s extractFingerPrintt) String(a []byte) string {
	var tmp []string
	for _, b := range a {
		tmp = append(tmp, strconv.FormatUint(uint64(b), 10))
	}
	fingerprint := strings.Join(tmp, ",")
	return fingerprint
}
func (s extractFingerPrintt) Encode(a string) []byte {
	return []byte(a)
}

// Tlv var
var Tlv = TlvList{
	Tlvlist: map[int]TlvType{
		0:   TlvType{"Pad", tlvIPAddr},
		1:   TlvType{"OptionSubnetMask", tlvIPAddr},
		2:   TlvType{"OptionTimeOffset", tlvSTime},
		3:   TlvType{"OptionRouter", tlvIPAddr},
		4:   TlvType{"OptionTimeServer", tlvIPAddr},
		5:   TlvType{"OptionNameServer", tlvIPAddr},
		6:   TlvType{"OptionDomainNameServer", tlvIPAddr},
		7:   TlvType{"OptionLogServer", tlvIPAddr},
		8:   TlvType{"OptionCookieServer", tlvIPAddr},
		9:   TlvType{"OptionLPRServer", tlvIPAddr},
		10:  TlvType{"OptionImpressServer", tlvIPAddr},
		11:  TlvType{"OptionResourceLocationServer", tlvIPAddr},
		12:  TlvType{"OptionHostName", tlvNstring},
		13:  TlvType{"OptionBootFileSize", tlvShort},
		14:  TlvType{"OptionMeritDumpFile", tlvNstring},
		15:  TlvType{"OptionDomainName", tlvNstring},
		16:  TlvType{"OptionSwapServer", tlvIPAddr},
		17:  TlvType{"OptionRootPath", tlvNstring},
		18:  TlvType{"OptionExtensionsPath", tlvNstring},
		19:  TlvType{"OptionIPForwardingEnableDisable", tlvBool},
		20:  TlvType{"OptionNonLocalSourceRoutingEnableDisable", tlvBool},
		21:  TlvType{"OptionPolicyFilter", tlvIPAddr},
		22:  TlvType{"OptionMaximumDatagramReassemblySize", tlvShort},
		23:  TlvType{"OptionDefaultIPTimeToLive", tlvRangeByte},
		24:  TlvType{"OptionPathMTUAgingTimeout", tlvSTime},
		25:  TlvType{"OptionPathMTUPlateauTable", tlvRangeShort},
		26:  TlvType{"OptionInterfaceMTU", tlvRangeShort},
		27:  TlvType{"OptionAllSubnetsAreLocal", tlvBool},
		28:  TlvType{"OptionBroadcastAddress", tlvIPAddr},
		29:  TlvType{"OptionPerformMaskDiscovery", tlvBool},
		30:  TlvType{"OptionMaskSupplier", tlvBool},
		31:  TlvType{"OptionPerformRouterDiscovery", tlvBool},
		32:  TlvType{"OptionRouterSolicitationAddress", tlvIPAddr},
		33:  TlvType{"OptionStaticRoute", tlvIPAddr},
		34:  TlvType{"OptionTrailerEncapsulation", tlvBool},
		35:  TlvType{"OptionARPCacheTimeout", tlvSTime},
		36:  TlvType{"OptionEthernetEncapsulation", tlvBool},
		37:  TlvType{"OptionTCPDefaultTTL", tlvRangeByte},
		38:  TlvType{"OptionTCPKeepaliveInterval", tlvSTime},
		39:  TlvType{"OptionTCPKeepaliveGarbage", tlvBool},
		40:  TlvType{"OptionNetworkInformationServiceDomain", tlvNstring},
		41:  TlvType{"OptionNetworkInformationServers", tlvIPAddr},
		42:  TlvType{"OptionNetworkTimeProtocolServers", tlvIPAddr},
		43:  TlvType{"OptionVendorSpecificInformation", tlvBlob},
		44:  TlvType{"OptionNetBIOSOverTCPIPNameServer", tlvIPAddr},
		45:  TlvType{"OptionNetBIOSOverTCPIPDatagramDistributionServer", tlvIPAddr},
		46:  TlvType{"OptionNetBIOSOverTCPIPNodeType", tlvRangeByte},
		47:  TlvType{"OptionNetBIOSOverTCPIPScope", tlvNstring},
		48:  TlvType{"OptionXWindowSystemFontServer", tlvIPAddr},
		49:  TlvType{"OptionXWindowSystemDisplayManager", tlvIPAddr},
		50:  TlvType{"OptionRequestedIPAddress", tlvIPAddr},
		51:  TlvType{"OptionIPAddressLeaseTime", tlvSTime},
		52:  TlvType{"OptionOverload", tlvOverload},
		53:  TlvType{"OptionDHCPMessageType", tlvMessage},
		54:  TlvType{"OptionServerIdentifier", tlvIPAddr},
		55:  TlvType{"OptionParameterRequestList", extractFingerPrint},
		56:  TlvType{"OptionMessage", tlvNstring},
		57:  TlvType{"OptionMaximumDHCPMessageSize", tlvShort},
		58:  TlvType{"OptionRenewalTimeValue", tlvSTime},
		59:  TlvType{"OptionRebindingTimeValue", tlvSTime},
		60:  TlvType{"OptionVendorClassIdentifier", tlvSTime},
		61:  TlvType{"OptionClientIdentifier", tlvBlob},
		62:  TlvType{"OptionNetwareIPDomain", tlvNstring},
		63:  TlvType{"OptionNetwareIPInformation", tlvBlob},
		64:  TlvType{"OptionNetworkInformationServicePlusDomain", tlvNstring},
		65:  TlvType{"OptionNetworkInformationServicePlusServers", tlvIPAddr},
		66:  TlvType{"OptionTFTPServerName", tlvNstring},
		67:  TlvType{"OptionBootFileName", tlvNstring},
		68:  TlvType{"OptionMobileIPHomeAgent", tlvIPAddr},
		69:  TlvType{"OptionSimpleMailTransportProtocol", tlvIPAddr},
		70:  TlvType{"OptionPostOfficeProtocolServer", tlvIPAddr},
		71:  TlvType{"OptionNetworkNewsTransportProtocol", tlvIPAddr},
		72:  TlvType{"OptionDefaultWorldWideWebServer", tlvIPAddr},
		73:  TlvType{"OptionDefaultFingerServer", tlvIPAddr},
		74:  TlvType{"OptionDefaultInternetRelayChatServer", tlvIPAddr},
		75:  TlvType{"OptionStreetTalkServer", tlvIPAddr},
		76:  TlvType{"OptionStreetTalkDirectoryAssistance", tlvIPAddr},
		77:  TlvType{"OptionUserClass", TlvTypeCn},
		81:  TlvType{"OptionFQDN", tlvNstring},
		82:  TlvType{"OptionRelayAgentInformation", tlvBlob},
		93:  TlvType{"OptionClientArchitecture", tlvShort},
		100: TlvType{"OptionTZPOSIXString", tlvNstring},
		101: TlvType{"OptionTZDatabaseString", tlvNstring},
		121: TlvType{"OptionClasslessRouteFormat", tlvBlob},
		255: TlvType{"end", tlvZeroSize},
	},
}
