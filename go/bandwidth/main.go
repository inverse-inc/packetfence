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
			fmt.Println(err.Error())
		}

		if err := nf.Decode(message[:rlen]); err != nil {
			fmt.Println(err.Error())
		}
		if nf.Version != 5 {
			fmt.Println("Invalid version")
		}
		if nf.Count != 30 {
			fmt.Println("Invalid record count")
		}

		spew.Dump(nf.Recs)
	}
}
