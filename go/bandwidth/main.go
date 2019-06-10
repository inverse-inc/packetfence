package main

import (
	"fmt"
	"github.com/davecgh/go-spew/spew"
	"github.com/gravwell/netflow"
	"net"
)

func main() {
	var nf netflow.NFv5
	conn, err := net.ListenUDP("udp", &net.UDPAddr{
		Port: 2055,
		IP:   net.ParseIP("0.0.0.0"),
	})
	if err != nil {
		panic(err)
	}

	defer conn.Close()
	fmt.Printf("server listening %s\n", conn.LocalAddr().String())

	for {
		message := make([]byte, 1464)
		rlen, _, err := conn.ReadFromUDP(message[:])
		if err != nil {
			panic(err)
		}

		if err := nf.Decode(message[:rlen]); err != nil {
			panic(err)
		}
		if nf.Version != 5 {
			panic("Invalid version")
		}
		if nf.Count != 30 {
			panic("Invalid record count")
		}

		spew.Dump(nf.Recs)
	}
}
