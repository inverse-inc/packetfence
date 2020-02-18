package main

import (
	"context"
	"fmt"
	"layeh.com/radius"
	"layeh.com/radius/rfc2866"
	"net"
	"testing"
	"time"
)

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
		SecretSource: radius.StaticSecretSource(secret),
		Handler:      NewPfRadius(),
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
		if response.Code != radius.CodeAccessReject {
			clientErr = fmt.Errorf("expected CodeAccessReject, got %s", response.Code)
		}
		if clientErr != nil {
			fmt.Println(nil)
		}
	}()

	if err := server.Serve(pc); err != nil && err != radius.ErrServerShutdown {
		t.Fatal(err)
	}

	//server.Shutdown(context.Background())

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
		SecretSource: radius.StaticSecretSource(secret),
		Handler:      NewPfRadius(),
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
