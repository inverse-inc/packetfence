package pfipset

import (
	"context"
	"fmt"
	"runtime"
	"sync"

	ipset "github.com/inverse-inc/go-ipset/v2"
	"github.com/inverse-inc/go-utils/log"
	"github.com/ti-mo/netfilter"
)

type job struct {
	Method string
	Set    string
	Entry  *ipset.Entry
}

func doWork(id int, job job) {
	logger := log.LoggerWContext(context.Background())
	conn := getConn()
	defer putConn(conn)
	if job.Method == "Add" {
		err := conn.Add(job.Set, job.Entry)
		if err != nil {
			logger.Error(fmt.Sprintf("Error with %s to set %s: %s", job.Method, job.Set, err.Error()))
		}
	}
	if job.Method == "Del" {
		err := conn.Delete(job.Set, job.Entry)
		if err != nil {
			logger.Error(fmt.Sprintf("Error with %s to set %s: %s", job.Method, job.Set, err.Error()))
		}
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
