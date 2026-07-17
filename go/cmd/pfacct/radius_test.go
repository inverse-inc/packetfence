package main

import (
	"context"
	"encoding/binary"
	"fmt"
	"net"
	"reflect"
	"testing"
	"time"

	"github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/rfc2865"
	"github.com/inverse-inc/go-radius/rfc2866"
	"github.com/inverse-inc/go-radius/vendors/cisco"
	"github.com/inverse-inc/packetfence/go/pfradius"
)

type SecretSourceFunc func(ctx context.Context, remoteAddr net.Addr, raw []byte) ([]byte, context.Context, error)

func (f SecretSourceFunc) RADIUSSecret(ctx context.Context, remoteAddr net.Addr, raw []byte) ([]byte, context.Context, error) {
	return f(ctx, remoteAddr, raw)
}

func TestPacketServer_reject(t *testing.T) {
	addr, err := net.ResolveUDPAddr("udp", "localhost:0")
	if err != nil {
		t.Fatal(err)
	}
	pc, err := net.ListenUDP("udp", addr)
	if err != nil {
		t.Fatal(err)
	}

	secret := []byte("123456790")
	const UserNameType = 1
	server := radius.PacketServer{
		SecretSource: SecretSourceFunc(
			func(ctx context.Context, remoteAddr net.Addr, raw []byte) ([]byte, context.Context, error) {
				return secret, context.WithValue(ctx, switchInfoKey, &SwitchInfo{}), nil
			},
		),
		Handler: NewPfAcct("INFO"),
	}

	var clientErr error
	go func() {
		defer server.Shutdown(context.Background())

		packet := radius.New(radius.CodeAccountingRequest, secret)
		username, _ := radius.NewString("tim")
		packet.Set(UserNameType, username)
		client := radius.Client{
			Retry: time.Millisecond * 50,
		}
		response, err := client.Exchange(context.Background(), packet, pc.LocalAddr().String())
		if err != nil {
			clientErr = err
			return
		}
		if response.Code != radius.CodeAccountingResponse {
			clientErr = fmt.Errorf("expected CodeAccountingResponse, got %s", response.Code)
		}
		if clientErr != nil {
			fmt.Println(nil)
		}
	}()

	if err := server.Serve(pc); err != nil && err != radius.ErrServerShutdown {
		t.Fatal(err)
	}

	if clientErr != nil {
		t.Fatal(clientErr)
	}
}

func TestPacketServer_start(t *testing.T) {
	packetServerTestStatusCode(t, rfc2866.AcctStatusType_Value_Start)
}

func TestPacketServer_update(t *testing.T) {
	packetServerTestStatusCode(t, rfc2866.AcctStatusType_Value_InterimUpdate)
}

func TestPacketServer_stop(t *testing.T) {
	packetServerTestStatusCode(t, rfc2866.AcctStatusType_Value_Stop)
}

func packetServerTestStatusCode(t *testing.T, statusType rfc2866.AcctStatusType) {
	addr, err := net.ResolveUDPAddr("udp", "localhost:0")
	if err != nil {
		t.Fatal(err)
	}
	pc, err := net.ListenUDP("udp", addr)
	if err != nil {
		t.Fatal(err)
	}

	secret := []byte("123456790")
	const UserNameType = 1

	server := radius.PacketServer{
		SecretSource: SecretSourceFunc(
			func(ctx context.Context, remoteAddr net.Addr, raw []byte) ([]byte, context.Context, error) {
				return secret, context.WithValue(ctx, switchInfoKey, &SwitchInfo{}), nil
			},
		),
		Handler: NewPfAcct("INFO"),
	}

	var clientErr error
	go func() {
		defer server.Shutdown(context.Background())

		packet := radius.New(radius.CodeAccountingRequest, secret)
		username, _ := radius.NewString("tim")
		packet.Set(UserNameType, username)
		rfc2866.AcctStatusType_Add(packet, statusType)
		packet.Set(UserNameType, username)
		client := radius.Client{
			Retry: time.Millisecond * 50,
		}
		response, err := client.Exchange(context.Background(), packet, pc.LocalAddr().String())
		if err != nil {
			clientErr = err
			return
		}
		if response.Code != radius.CodeAccountingResponse {
			clientErr = fmt.Errorf("expected Accounting-Response, got %s", response.Code)
		}
		if clientErr != nil {
			fmt.Println(nil)
		}
	}()

	if err := server.Serve(pc); err != nil && err != radius.ErrServerShutdown {
		t.Fatal(err)
	}

	if clientErr != nil {
		t.Fatal(clientErr)
	}
}

func TestPacketToMap(t *testing.T) {
	packet := radius.New(radius.CodeAccountingRequest, []byte("bob"))
	rfc2865.UserName_SetString(packet, "tim")
	cisco.CiscoAVPair_AddString(packet, "bob=bobby")
	cisco.CiscoAVPair_AddString(packet, "j=r")
	attributeMap := packetToMap(context.Background(), packet)
	expected := map[string]interface{}{"User-Name": "tim", "Cisco-AVPair": []interface{}{"bob=bobby", "j=r"}}
	if reflect.DeepEqual(expected, attributeMap) == false {
		t.Errorf("expected : %v, got : %v", expected, attributeMap)
	}
}

// vendorVSA builds an attribute-26 Vendor-Specific value the way RADIUSSecret
// sees it after radius.ParseAttributes:
// [vendor-id:4][vendor-type:1][vendor-length:1][data...].
func vendorVSA(vendorID uint32, vendorType byte, data string) radius.Attribute {
	vsa := make(radius.Attribute, 6+len(data))
	binary.BigEndian.PutUint32(vsa[:4], vendorID)
	vsa[4] = vendorType
	vsa[5] = byte(2 + len(data))
	copy(vsa[6:], data)
	return vsa
}

func attrsWith(vsas ...radius.Attribute) radius.Attributes {
	a := radius.Attributes{}
	for _, v := range vsas {
		a.Add(26, v)
	}
	return a
}

// hasPacketFenceConnectorID gates whether accounting is validated/answered with
// the unified connector secret instead of the inner switch's secret. A false
// negative would reject legitimate connector accounting; a false positive would
// answer normal NAS accounting with the wrong secret.
func TestHasPacketFenceConnectorID(t *testing.T) {
	tests := []struct {
		name  string
		attrs radius.Attributes
		want  bool
	}{
		{
			name:  "no attributes",
			attrs: radius.Attributes{},
			want:  false,
		},
		{
			name:  "matching PacketFence-ConnectorID VSA",
			attrs: attrsWith(vendorVSA(pfradius.VendorID, pfradius.ConnectorIDAttrType, "connectorA")),
			want:  true,
		},
		{
			name:  "right vendor, wrong attribute type",
			attrs: attrsWith(vendorVSA(pfradius.VendorID, pfradius.ConnectorIDAttrType-1, "connectorA")),
			want:  false,
		},
		{
			name:  "wrong vendor id",
			attrs: attrsWith(vendorVSA(9, pfradius.ConnectorIDAttrType, "connectorA")),
			want:  false,
		},
		{
			name: "unrelated VSA present alongside the ConnectorID VSA",
			attrs: attrsWith(
				vendorVSA(9, 1, "somethingelse"),
				vendorVSA(pfradius.VendorID, pfradius.ConnectorIDAttrType, "connectorA"),
			),
			want: true,
		},
		{
			name:  "truncated VSA (shorter than 5 bytes) is ignored, not a panic",
			attrs: attrsWith(radius.Attribute{0x00, 0x00, 0x73}),
			want:  false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := hasPacketFenceConnectorID(tc.attrs); got != tc.want {
				t.Errorf("hasPacketFenceConnectorID() = %v, want %v", got, tc.want)
			}
		})
	}
}
