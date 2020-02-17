package main

import (
    "testing"
	"layeh.com/radius"
	 _ "layeh.com/radius/rfc2866"
	"context"
	"fmt"
	"net"
	"time"
)

func TestRadius(t *testing.T) {

}

func TestPacketServer_basic(t *testing.T) {
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
		Handler: radius.HandlerFunc(HandleRadius),
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
			clientErr = fmt.Errorf("expected CodeAccessAccept, got %s", response.Code)
		}
        if (clientErr != nil) {
            fmt.Println(nil)
        }
	}()

	if err := server.Serve(pc); err != nil && err != radius.ErrServerShutdown {
		t.Fatal(err)
	}

	//server.Shutdown(context.Background())

	if clientErr != nil {
		t.Fatal(err)
	}
}
