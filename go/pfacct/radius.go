package main

import (
	"log"
	"net"
    "sync"

	"layeh.com/radius"
	"layeh.com/radius/rfc2866"
)

func HandleRadius(w radius.ResponseWriter, r *radius.Request) {
	in_bytes := uint64(rfc2866.AcctInputOctets_Get(r.Packet))
	out_bytes := uint64(rfc2866.AcctOutputOctets_Get(r.Packet))
	statusType := rfc2866.AcctStatusType_Get(r.Packet)
	_, _ = in_bytes, out_bytes
	switch statusType {
	case rfc2866.AcctStatusType_Value_Start:
	case rfc2866.AcctStatusType_Value_Stop:
	case rfc2866.AcctStatusType_Value_InterimUpdate:
	}

	code := radius.CodeAccountingResponse
	log.Printf("Writing %v to %v", code, r.RemoteAddr)
	w.Write(r.Response(code))
}

func radiusListen(w *sync.WaitGroup) *radius.PacketServer {
	addr, err := net.ResolveUDPAddr("udp", "localhost:1813")
	if err != nil {
		panic(err)
	}
	pc, err := net.ListenUDP("udp", addr)
	if err != nil {
		panic(err)
	}

	server := &radius.PacketServer{
		Handler:      radius.HandlerFunc(HandleRadius),
		SecretSource: radius.StaticSecretSource([]byte(`secret`)),
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
