package main

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"os"

	"github.com/Sereal/Sereal/Go/sereal"
)

const socketPath = "/usr/local/pf/var/run/pfconfig-go.sock"

func main() {
	_ = os.Remove(socketPath)
	l, err := net.Listen("unix", socketPath)
	if err != nil {
		log.Fatal(err)
	}
	defer l.Close()
	for {
		conn, err := l.Accept()
		if err != nil {
			fmt.Print(err)
		}
		defer conn.Close()
		scanner := bufio.NewScanner(conn)
		for scanner.Scan() {
			data := scanner.Text()
			fmt.Print(string(data), "")
		}
		if err := scanner.Err(); err != nil {
			fmt.Print(err)
		}
	}
}

func test() {
	_ = sereal.NewEncoderV3()
}
