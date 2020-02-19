package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"sync"

	"github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/dictionary"
	"github.com/inverse-inc/go-radius/rfc2865"
	"github.com/inverse-inc/go-radius/rfc2866"
)

var radiusDictionary *dictionary.Dictionary

func (h *PfAcct) ServeRADIUS(w radius.ResponseWriter, r *radius.Request) {
	in_bytes := uint64(rfc2866.AcctInputOctets_Get(r.Packet))
	out_bytes := uint64(rfc2866.AcctOutputOctets_Get(r.Packet))
	statusType := rfc2866.AcctStatusType_Get(r.Packet)
	_, _ = in_bytes, out_bytes
	switch statusType {
	default:
		w.Write(r.Response(radius.CodeAccessReject))
	case rfc2866.AcctStatusType_Value_Start:
		h.handleStart(w, r)
	case rfc2866.AcctStatusType_Value_Stop:
		h.handleStop(w, r)
	case rfc2866.AcctStatusType_Value_InterimUpdate:
		h.handleUpdate(w, r)
	case rfc2866.AcctStatusType_Value_AccountingOn:
		h.handleAccountingOn(w, r)
	case rfc2866.AcctStatusType_Value_AccountingOff:
		h.handleAccountingOff(w, r)
	}
}

func (h *PfAcct) handleStart(w radius.ResponseWriter, r *radius.Request) {
	code := radius.CodeAccountingResponse
	log.Printf("Writing %v to %v", code, r.RemoteAddr)
	w.Write(r.Response(code))
}

func (h *PfAcct) handleAccountingOn(w radius.ResponseWriter, r *radius.Request) {
	code := radius.CodeAccountingResponse
	log.Printf("Writing %v to %v", code, r.RemoteAddr)
	w.Write(r.Response(code))
}

func (h *PfAcct) handleAccountingOff(w radius.ResponseWriter, r *radius.Request) {
	code := radius.CodeAccountingResponse
	log.Printf("Writing %v to %v", code, r.RemoteAddr)
	w.Write(r.Response(code))
}

func (h *PfAcct) handleStop(w radius.ResponseWriter, r *radius.Request) {
	code := radius.CodeAccountingResponse
	log.Printf("Writing %v to %v", code, r.RemoteAddr)
	w.Write(r.Response(code))
}

func (h *PfAcct) handleUpdate(w radius.ResponseWriter, r *radius.Request) {
	code := radius.CodeAccountingResponse
	log.Printf("Writing %v to %v", code, r.RemoteAddr)
	w.Write(r.Response(code))
}

func (h *PfAcct) radiusListen(w *sync.WaitGroup) *radius.PacketServer {
	addr, err := net.ResolveUDPAddr("udp", "localhost:1813")
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

func (h *PfAcct) RADIUSSecret(ctx context.Context, remoteAddr net.Addr, raw []byte) ([]byte, error) {
	return nil, nil
}

func packetToMap(p *radius.Packet) map[string]interface{} {
	attributes := make(map[string]interface{})
	for i, attr := range p.Attributes {
		if rfc2865.VendorSpecific_Type == i {
			for _, vattrs := range attr {
				id, vsa, err := radius.VendorSpecific(vattrs)
				if err != nil {
					fmt.Printf("Problems\n")
					continue
				}

				v := dictionary.VendorByNumber(radiusDictionary.Vendors, uint(id))
				if v == nil {
					fmt.Printf("Problems\n")
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
				fmt.Printf("Problems\n")
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
