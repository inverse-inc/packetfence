package pfipset

import (
	ipset "github.com/inverse-inc/go-ipset/v2"
	"github.com/ti-mo/netfilter"
	"runtime"
	"sync"
)

type job struct {
	Method string
	Set    string
	Entry  *ipset.Entry
}

func doWork(id int, jobe job) {
	conn := getConn()
	defer putConn(conn)
	if jobe.Method == "Add" {
		conn.Add(jobe.Set, jobe.Entry)
	}
	if jobe.Method == "Del" {
		conn.Delete(jobe.Set, jobe.Entry)
	}
}

func closeConn(conn *ipset.Conn) {
	conn.Close()
}

var connPool = sync.Pool{
	New: func() interface{} {
		conn, _ := ipset.Dial(netfilter.ProtoUnspec, nil)
		runtime.SetFinalizer(conn, closeConn)
		return conn
	},
}

func getConn() *ipset.Conn {
	conn := connPool.Get().(*ipset.Conn)
	return conn
}

func putConn(conn *ipset.Conn) {
	connPool.Put(conn)
}
