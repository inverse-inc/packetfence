package pfqueueclient

import (
	"encoding/binary"
	"encoding/json"
	"errors"
	"net"
	"os"

	"github.com/inverse-inc/packetfence/go/file_paths"
)

type ConnInfo struct {
	Pid int `json:"pid"`
}

type BackendConn struct {
	conn *net.UnixConn
	info ConnInfo
}

func NewBackendConn(name string) (*BackendConn, error) {
	addr := net.UnixAddr{Net: "unix", Name: file_paths.PFQUEUE_BACKEND_SOCKET}
	conn, err := net.DialUnix("unix", nil, &addr)
	if err != nil {
		return nil, err
	}

	_, err = SendTo(conn, []byte(name))
	if err != nil {
		conn.Close()
		return nil, err
	}

	data, err := ReadFrom(conn)
	if err != nil {
		conn.Close()
		return nil, err
	}

	c := &BackendConn{
		conn: conn,
	}

	if err := json.Unmarshal(data, &c.info); err != nil {
		return nil, err
	}

	return c, nil
}

func (c *BackendConn) Close() {
	c.conn.Close()
}

func (c *BackendConn) Kill() error {
	c.conn.Close()
	p, err := os.FindProcess(c.info.Pid)
	if err != nil {
		return nil
	}

	return p.Kill()
}

func (c *BackendConn) Send(data []byte) (interface{}, error) {
	data, err := c.sendRecv(data)
	if err != nil {
		return nil, err
	}

	var out interface{}
	if err := json.Unmarshal(data, &out); err != nil {
		return nil, err
	}

	return out, nil
}

func (c *BackendConn) sendRecv(data []byte) ([]byte, error) {
	if _, err := SendTo(c.conn, data); err != nil {
		return nil, err
	}

	return ReadFrom(c.conn)
}

func (c *BackendConn) Ping() bool {
	data, err := c.sendRecv([]byte("ping"))
	if err != nil {
		return false
	}

	var ping bool
	json.Unmarshal(data, &ping)
	return ping
}

func ReadFrom(conn *net.UnixConn) ([]byte, error) {
	buff := [4096]byte{}
	bytes := buff[:]
	n, err := conn.Read(bytes)
	if err != nil {
		return nil, err
	}

	if n < 4 {
		return nil, errors.New("Short Read")
	}

	got := n - 4
	expect := int(binary.LittleEndian.Uint32(bytes[:]))
	data := make([]byte, expect, expect)
	copy(data[0:got], bytes[4:n])
	if got != expect {
		for got < expect {
			n, err := conn.Read(data[got:])
			if err != nil {
				return nil, err
			}
			got += n
		}
	}

	return data, nil
}

func SendTo(conn *net.UnixConn, data []byte) (int, error) {
	buff := [4]byte{}
	to_send := len(data)
	binary.LittleEndian.PutUint32(buff[:], uint32(to_send))
	n, err := conn.Write(buff[:])
	if err != nil {
		return 0, err
	}

	if n != 4 {
		return 0, errors.New("Short Write")
	}

	sent, err := conn.Write(data)
	if err != nil {
		return sent, err
	}

	for sent < to_send {
		n, err := conn.Write(data[sent:])
		if err != nil {
			return sent + n, err
		}

		sent += n
	}

	return sent, err
}
