package radius_proxy

import (
	"encoding/hex"
	"strconv"

	"github.com/inverse-inc/go-radius/dictionary"
	"github.com/inverse-inc/packetfence/go/chisel/share/cio"
	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
)

func LogPacket(l *cio.Logger, p *radius.Packet) {
	l.Printf("Radius packet %s", p.Code.String())
	l.Printf("Attributes")
	for _, a := range p.Attributes {
		if rfc2865.VendorSpecific_Type == a.Type {
			id, vsa, err := radius.VendorSpecific(a.Attribute)
			if err != nil {
				continue
			}
			v := radiusDictionary.GetVendorByNumber(uint(id))
			if v == nil {
				continue
			}
			for len(vsa) >= 3 {
				vsaTyp, vsaLen := vsa[0], vsa[1]
				data := vsa[2:int(vsaLen)]
				dictAttr := dictionary.AttributeByOID(v.Attributes, []int{int(vsaTyp)})
				vsa = vsa[int(vsaLen):]
				if dictAttr == nil {
					continue
				}

				l.Printf("\t%s => %s", dictAttr.Name, AttributeToString(dictAttr, radius.Attribute(data)))
			}
		} else {
			dictAttr := radiusDictionary.GetAttributeByOID([]int{int(a.Type)})
			l.Printf("\t%s => %s", dictAttr.Name, AttributeToString(dictAttr, a.Attribute))
		}
	}
}

/*
	AttributeString
	AttributeOctets
	AttributeIPAddr
	AttributeDate
	AttributeInteger
	AttributeIPv6Addr
	AttributeIPv6Prefix
	AttributeIFID
	AttributeInteger64

	AttributeVSA

	AttributeEther
	AttributeABinary
	AttributeByte
	AttributeShort
	AttributeSigned
	AttributeTLV
	AttributeIPv4Prefix

*/

func AttributeToString(da *dictionary.Attribute, attr radius.Attribute) string {
	switch da.Type {
	case dictionary.AttributeString:
		return radius.String(attr)
	case dictionary.AttributeByte:
		return strconv.FormatUint(uint64(attr[0]), 10)
	case dictionary.AttributeShort:
		i, err := radius.Short(attr)
		if err == nil {
			return strconv.FormatUint(uint64(i), 10)
		}
	case dictionary.AttributeSigned:
		i, err := radius.Integer(attr)
		if err == nil {
			return strconv.FormatInt(int64(int32(i)), 10)
		}
	case dictionary.AttributeInteger:
		i, err := radius.Integer(attr)
		if err == nil {
			return strconv.FormatUint(uint64(i), 10)
		}
	case dictionary.AttributeInteger64:
		i, err := radius.Integer64(attr)
		if err == nil {
			return strconv.FormatUint(i, 10)
		}
	case dictionary.AttributeIPAddr:
		i, err := radius.IPAddr(attr)
		if err == nil {
			return i.String()
		}
	case dictionary.AttributeIPv6Addr:
		i, err := radius.IPv6Addr(attr)
		if err == nil {
			return i.String()
		}
	case dictionary.AttributeDate:
		i, err := radius.Date(attr)
		if err == nil {
			return i.String()
		}
	}
	return "0x" + hex.EncodeToString(attr)
}
