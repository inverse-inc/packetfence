package main

import (
	"context"
	"fmt"
	"github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/rfc2865"
	"github.com/inverse-inc/go-radius/rfc2866"
	"github.com/inverse-inc/go-radius/vendors/cisco"
	"net"
	"reflect"
	"testing"
	"time"
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
		Handler: NewPfAcct(),
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
		Handler: NewPfAcct(),
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
