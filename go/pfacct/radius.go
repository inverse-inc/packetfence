package main

import (
	"context"
	"log"
	"net"
	"sync"

	"github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/rfc2866"
)

type PfRadius struct {
}

func NewPfRadius() *PfRadius {
	return &PfRadius{}
}

func (h *PfRadius) ServeRADIUS(w radius.ResponseWriter, r *radius.Request) {
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

func (h *PfRadius) handleStart(w radius.ResponseWriter, r *radius.Request) {
	code := radius.CodeAccountingResponse
	log.Printf("Writing %v to %v", code, r.RemoteAddr)
	w.Write(r.Response(code))
}

func (h *PfRadius) handleAccountingOn(w radius.ResponseWriter, r *radius.Request) {
	code := radius.CodeAccountingResponse
	log.Printf("Writing %v to %v", code, r.RemoteAddr)
	w.Write(r.Response(code))
}

func (h *PfRadius) handleAccountingOff(w radius.ResponseWriter, r *radius.Request) {
	code := radius.CodeAccountingResponse
	log.Printf("Writing %v to %v", code, r.RemoteAddr)
	w.Write(r.Response(code))
}

func (h *PfRadius) handleStop(w radius.ResponseWriter, r *radius.Request) {
	code := radius.CodeAccountingResponse
	log.Printf("Writing %v to %v", code, r.RemoteAddr)
	w.Write(r.Response(code))
}

func (h *PfRadius) handleUpdate(w radius.ResponseWriter, r *radius.Request) {
	code := radius.CodeAccountingResponse
	log.Printf("Writing %v to %v", code, r.RemoteAddr)
	w.Write(r.Response(code))
}

func (h *PfRadius) radiusListen(w *sync.WaitGroup) *radius.PacketServer {
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

func (h *PfRadius) RADIUSSecret(ctx context.Context, remoteAddr net.Addr, raw []byte) ([]byte, error) {
	return nil, nil
}
