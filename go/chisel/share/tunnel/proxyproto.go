package tunnel

import (
	"errors"
	"io"
	"net"

	"github.com/pires/go-proxyproto"
)

// ProxyProtocolHandler is the remote handler ("host:port/tcp|proxyproto")
// that prefixes every tunnelled TCP connection with a PROXY protocol v2
// header carrying the client's source address and the local destination
// address. The target (haproxy-portal with `accept-proxy`) then knows the
// real client behind the connector instead of the tunnel exit address.
const ProxyProtocolHandler = "proxyproto"

// writeProxyProtocolHeader writes the PROXY v2 header describing src to w.
// src must be a net.Conn (the accepted client connection); anything else
// (stdio) cannot be described and is refused.
func writeProxyProtocolHeader(w io.Writer, src io.ReadWriteCloser) error {
	conn, ok := src.(net.Conn)
	if !ok {
		return errors.New("PROXY protocol requires a TCP client connection")
	}
	header := proxyproto.HeaderProxyFromAddrs(2, conn.RemoteAddr(), conn.LocalAddr())
	_, err := header.WriteTo(w)
	return err
}
