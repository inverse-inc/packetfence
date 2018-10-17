package main

import (
	"encoding/binary"
	"encoding/hex"
	"net"
	"strconv"
	"strings"
)

type TlvList struct {
	Tlvlist map[int]TlvType
}

type TlvType struct {
	Option string
	Decode DataType
}

type DataType interface {
	Value(a []byte) interface{}
	String(a []byte) string
}

var tlvIpAddr tlvIpAddrt

type tlvIpAddrt struct{}

func (s tlvIpAddrt) Value(a []byte) interface{} {
	return a
}
func (s tlvIpAddrt) String(a []byte) string {
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

var tlvNstring tlvNstringt

type tlvNstringt struct{}

func (s tlvNstringt) Value(a []byte) interface{} {
	return a
}
func (s tlvNstringt) String(a []byte) string {
	return string(a)
}

var tlvBlob tlvBlobt

type tlvBlobt struct{}

func (s tlvBlobt) Value(a []byte) interface{} {
	return a
}
func (s tlvBlobt) String(a []byte) string {
	return hex.EncodeToString(a)
}

var tlvSTime tlvSTimet

type tlvSTimet struct{}

func (s tlvSTimet) Value(a []byte) interface{} {
	return a
}
func (s tlvSTimet) String(a []byte) string {
	return string(a)
}

var tlvZeroSize tlvZeroSizet

type tlvZeroSizet struct{}

func (s tlvZeroSizet) Value(a []byte) interface{} {
	return a
}
func (s tlvZeroSizet) String(a []byte) string {
	return "string"
}

var tlvShort tlvShortt

type tlvShortt struct{}

func (s tlvShortt) Value(a []byte) interface{} {
	return a
}
func (s tlvShortt) String(a []byte) string {
	return strconv.Itoa(int(binary.BigEndian.Uint16(a)))
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

var tlvRangeShort tlvRangeShortt

type tlvRangeShortt struct{}

func (s tlvRangeShortt) Value(a []byte) interface{} {
	return a
}
func (s tlvRangeShortt) String(a []byte) string {
	return "string"
}

var tlvOverload tlvOverloadt

type tlvOverloadt struct{}

func (s tlvOverloadt) Value(a []byte) interface{} {
	return a
}
func (s tlvOverloadt) String(a []byte) string {
	return "string"
}

var tlvMessage tlvMessaget

type tlvMessaget struct{}

func (s tlvMessaget) Value(a []byte) interface{} {
	return a
}
func (s tlvMessaget) String(a []byte) string {
	return strconv.Itoa(int(a[0]))
}

var tlvInt8 tlvInt8t

type tlvInt8t struct{}

func (s tlvInt8t) Value(a []byte) interface{} {
	return a
}
func (s tlvInt8t) String(a []byte) string {
	return hex.EncodeToString(a)
}

var TlvTypeCn TlvTypeCnt

type TlvTypeCnt struct{}

func (s TlvTypeCnt) Value(a []byte) interface{} {
	return a
}
func (s TlvTypeCnt) String(a []byte) string {
	return "string"
}

var tlvRangeByte tlvRangeBytet

type tlvRangeBytet struct{}

func (s tlvRangeBytet) Value(a []byte) interface{} {
	return a
}
func (s tlvRangeBytet) String(a []byte) string {
	return "string"
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

var Tlv = TlvList{
	Tlvlist: map[int]TlvType{
		0:   TlvType{"Pad", tlvIpAddr},
		1:   TlvType{"OptionSubnetMask", tlvIpAddr},
		2:   TlvType{"OptionTimeOffset", tlvSTime},
		3:   TlvType{"OptionRouter", tlvIpAddr},
		4:   TlvType{"OptionTimeServer", tlvIpAddr},
		5:   TlvType{"OptionNameServer", tlvIpAddr},
		6:   TlvType{"OptionDomainNameServer", tlvIpAddr},
		7:   TlvType{"OptionLogServer", tlvIpAddr},
		8:   TlvType{"OptionCookieServer", tlvIpAddr},
		9:   TlvType{"OptionLPRServer", tlvIpAddr},
		10:  TlvType{"OptionImpressServer", tlvIpAddr},
		11:  TlvType{"OptionResourceLocationServer", tlvIpAddr},
		12:  TlvType{"OptionHostName", tlvNstring},
		13:  TlvType{"OptionBootFileSize", tlvShort},
		14:  TlvType{"OptionMeritDumpFile", tlvNstring},
		15:  TlvType{"OptionDomainName", tlvNstring},
		16:  TlvType{"OptionSwapServer", tlvIpAddr},
		17:  TlvType{"OptionRootPath", tlvNstring},
		18:  TlvType{"OptionExtensionsPath", tlvNstring},
		19:  TlvType{"OptionIPForwardingEnableDisable", tlvBool},
		20:  TlvType{"OptionNonLocalSourceRoutingEnableDisable", tlvBool},
		21:  TlvType{"OptionPolicyFilter", tlvIpAddr},
		22:  TlvType{"OptionMaximumDatagramReassemblySize", tlvShort},
		23:  TlvType{"OptionDefaultIPTimeToLive", tlvRangeByte},
		24:  TlvType{"OptionPathMTUAgingTimeout", tlvSTime},
		25:  TlvType{"OptionPathMTUPlateauTable", tlvRangeShort},
		26:  TlvType{"OptionInterfaceMTU", tlvRangeShort},
		27:  TlvType{"OptionAllSubnetsAreLocal", tlvBool},
		28:  TlvType{"OptionBroadcastAddress", tlvIpAddr},
		29:  TlvType{"OptionPerformMaskDiscovery", tlvBool},
		30:  TlvType{"OptionMaskSupplier", tlvBool},
		31:  TlvType{"OptionPerformRouterDiscovery", tlvBool},
		32:  TlvType{"OptionRouterSolicitationAddress", tlvIpAddr},
		33:  TlvType{"OptionStaticRoute", tlvIpAddr},
		34:  TlvType{"OptionTrailerEncapsulation", tlvBool},
		35:  TlvType{"OptionARPCacheTimeout", tlvSTime},
		36:  TlvType{"OptionEthernetEncapsulation", tlvBool},
		37:  TlvType{"OptionTCPDefaultTTL", tlvRangeByte},
		38:  TlvType{"OptionTCPKeepaliveInterval", tlvSTime},
		39:  TlvType{"OptionTCPKeepaliveGarbage", tlvBool},
		40:  TlvType{"OptionNetworkInformationServiceDomain", tlvNstring},
		41:  TlvType{"OptionNetworkInformationServers", tlvIpAddr},
		42:  TlvType{"OptionNetworkTimeProtocolServers", tlvIpAddr},
		43:  TlvType{"OptionVendorSpecificInformation", tlvBlob},
		44:  TlvType{"OptionNetBIOSOverTCPIPNameServer", tlvIpAddr},
		45:  TlvType{"OptionNetBIOSOverTCPIPDatagramDistributionServer", tlvIpAddr},
		46:  TlvType{"OptionNetBIOSOverTCPIPNodeType", tlvRangeByte},
		47:  TlvType{"OptionNetBIOSOverTCPIPScope", tlvNstring},
		48:  TlvType{"OptionXWindowSystemFontServer", tlvIpAddr},
		49:  TlvType{"OptionXWindowSystemDisplayManager", tlvIpAddr},
		50:  TlvType{"OptionRequestedIPAddress", tlvIpAddr},
		51:  TlvType{"OptionIPAddressLeaseTime", tlvSTime},
		52:  TlvType{"OptionOverload", tlvOverload},
		53:  TlvType{"OptionDHCPMessageType", tlvMessage},
		54:  TlvType{"OptionServerIdentifier", tlvIpAddr},
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
		65:  TlvType{"OptionNetworkInformationServicePlusServers", tlvIpAddr},
		66:  TlvType{"OptionTFTPServerName", tlvNstring},
		67:  TlvType{"OptionBootFileName", tlvNstring},
		68:  TlvType{"OptionMobileIPHomeAgent", tlvIpAddr},
		69:  TlvType{"OptionSimpleMailTransportProtocol", tlvIpAddr},
		70:  TlvType{"OptionPostOfficeProtocolServer", tlvIpAddr},
		71:  TlvType{"OptionNetworkNewsTransportProtocol", tlvIpAddr},
		72:  TlvType{"OptionDefaultWorldWideWebServer", tlvIpAddr},
		73:  TlvType{"OptionDefaultFingerServer", tlvIpAddr},
		74:  TlvType{"OptionDefaultInternetRelayChatServer", tlvIpAddr},
		75:  TlvType{"OptionStreetTalkServer", tlvIpAddr},
		76:  TlvType{"OptionStreetTalkDirectoryAssistance", tlvIpAddr},
		77:  TlvType{"OptionUserClass", TlvTypeCn},
		82:  TlvType{"OptionRelayAgentInformation", tlvBlob},
		93:  TlvType{"OptionClientArchitecture", tlvShort},
		100: TlvType{"OptionTZPOSIXString", tlvNstring},
		101: TlvType{"OptionTZDatabaseString", tlvNstring},
		121: TlvType{"OptionClasslessRouteFormat", tlvBlob},
		255: TlvType{"end", tlvZeroSize},
	},
}
