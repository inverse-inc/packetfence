package reuseport

import (
	"net"
	"syscall"

	"golang.org/x/sys/unix"
)

func reusePort(network, address string, conn syscall.RawConn) error {
	var opErr error
	err := conn.Control(func(fd uintptr) {
		opErr = syscall.SetsockoptInt(int(fd), unix.SOL_SOCKET, unix.SO_REUSEPORT, 1)
	})
	if err != nil {
		return err
	}

	return opErr
}

var ReusePortListenConfig = net.ListenConfig{
	Control: reusePort,
}
