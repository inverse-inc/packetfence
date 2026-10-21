package reuseport

import (
	"context"
	"errors"
	"net"
)

func FreeTcpPort() (*net.TCPListener, int, error) {
	l, err := ReusePortListenConfig.Listen(context.Background(), "tcp", "localhost:0")
	if err != nil {
		return nil, 0, err
	}

	tl, ok := l.(*net.TCPListener)
	if !ok {
		return nil, 0, errors.New("Bad Cast")
	}

	addr, ok := l.Addr().(*net.TCPAddr)
	if !ok {
		return nil, 0, errors.New("Bad Cast")
	}

	return tl, addr.Port, nil
}

func FreeUdpPort() (*net.UDPConn, int, error) {
	l, err := ReusePortListenConfig.ListenPacket(context.Background(), "udp", "localhost:0")
	if err != nil {
		return nil, 0, err
	}

	uc, ok := l.(*net.UDPConn)
	if !ok {
		return nil, 0, errors.New("Bad Cast")
	}

	addr, ok := l.LocalAddr().(*net.UDPAddr)
	if !ok {
		return nil, 0, errors.New("Bad Cast")
	}

	return uc, addr.Port, nil
}
