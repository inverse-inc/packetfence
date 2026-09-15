package tunnel

import (
	"bufio"
	"bytes"
	"net"
	"testing"

	"github.com/inverse-inc/packetfence/go/chisel/share/settings"
	"github.com/pires/go-proxyproto"
)

type fakeConn struct {
	net.Conn
	remote, local net.Addr
}

func (f fakeConn) RemoteAddr() net.Addr { return f.remote }
func (f fakeConn) LocalAddr() net.Addr  { return f.local }

func TestWriteProxyProtocolHeader(t *testing.T) {
	src := fakeConn{
		remote: &net.TCPAddr{IP: net.IPv4(10, 10, 100, 50), Port: 51234},
		local:  &net.TCPAddr{IP: net.IPv4(10, 10, 100, 1), Port: 80},
	}
	var buf bytes.Buffer
	if err := writeProxyProtocolHeader(&buf, src); err != nil {
		t.Fatal(err)
	}
	h, err := proxyproto.Read(bufio.NewReader(&buf))
	if err != nil {
		t.Fatalf("header does not parse: %s", err)
	}
	if h.Version != 2 || h.Command != proxyproto.PROXY || h.TransportProtocol != proxyproto.TCPv4 {
		t.Errorf("version %d command %v proto %v", h.Version, h.Command, h.TransportProtocol)
	}
	if s := h.SourceAddr.String(); s != "10.10.100.50:51234" {
		t.Errorf("source %s", s)
	}
	if d := h.DestinationAddr.String(); d != "10.10.100.1:80" {
		t.Errorf("destination %s", d)
	}
}

type notAConn struct{}

func (notAConn) Read([]byte) (int, error)  { return 0, nil }
func (notAConn) Write([]byte) (int, error) { return 0, nil }
func (notAConn) Close() error              { return nil }

func TestWriteProxyProtocolHeaderRefusesNonConn(t *testing.T) {
	var buf bytes.Buffer
	if err := writeProxyProtocolHeader(&buf, notAConn{}); err == nil || buf.Len() != 0 {
		t.Errorf("expected an error and no output, got %v / %d bytes", err, buf.Len())
	}
}

func TestDecodeRemoteProxyProtocolHandler(t *testing.T) {
	r, err := settings.DecodeRemote("80:10.0.0.5:8880/tcp|proxyproto")
	if err != nil {
		t.Fatal(err)
	}
	if r.LocalPort != "80" || r.RemoteHost != "10.0.0.5" || r.RemotePort != "8880" || r.RemoteProto != "tcp" || r.Handler != ProxyProtocolHandler {
		t.Errorf("decoded %+v", r)
	}
	plain, _ := settings.DecodeRemote("80:10.0.0.5:80")
	if plain.Handler != "raw" {
		t.Errorf("default handler %q", plain.Handler)
	}
}
