package main

import (
	"context"
	"encoding/binary"
	"flag"
	"fmt"
	"net"
	"sync"
	"sync/atomic"
	"time"

	radius "github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/rfc2865"
	"github.com/inverse-inc/go-radius/rfc2866"
	"github.com/inverse-inc/go-radius/rfc2869"
)

var host = flag.String("host", "127.0.0.1", "The host to send the packets to")
var port = flag.String("port", "1813", "The port to send the packets to")
var secret = flag.String("secret", "secret", "The RADIUS secret to use")
var nasIpAddress = flag.String("nas-ip-address", "127.0.0.1", "The NAS-IP-Address to use in the packet")
var calledStationId = flag.String("called-station-id", "02:00:00:00:00:01", "The Called-Station-Id to use")
var nasPort = flag.Uint("nas-port", 20, "The Nas Port")

var nodesCount = flag.Int("lt-nodes-count", 1, "The amount of nodes to use while load-testing")
var minInterimPerNode = flag.Int("lt-min-interim-per-node", 0, "The minimal amount of interim updates per node while load-testing")
var maxInterimPerNode = flag.Int("lt-max-interim-per-node", 20, "The minimal amount of interim updates per node while load-testing")

var sessionIdPrefix = flag.String("session-id-prefix", "acct-tester-", "The prefix of the session IDs")

var concurrency = flag.Int("lt-concurrency", 1, "The amount of concurrent requests to send")

var workChans []chan pktinfo

var loadedChans uint64
var wg = &sync.WaitGroup{}

type pktinfo struct {
	t           rfc2866.AcctStatusType
	mac         string
	ip          net.IP
	inBytes     int
	outBytes    int
	sessionTime int
}

type endpointAcct struct {
	mac                string
	ip                 net.IP
	inBytesPerSession  int
	outBytesPerSession int
	sessionCount       int
}

func int2ip(nn uint32) net.IP {
	ip := make(net.IP, 4)
	binary.BigEndian.PutUint32(ip, nn)
	return ip
}

func loadTest(nodesCount, minInterimPerNode, maxInterimPerNode int) {
	wg.Add(1)
	defer wg.Done()

	eas := []endpointAcct{}

	// start at a00000000001
	startMac := 175921860444161
	// start at 10.0.0.1
	startIp := 167772161

	startInBytes := 1000
	startOutBytes := 2000

	for i := 0; i < nodesCount; i++ {
		// At least 2 sessions to have a start and a stop
		sessionCount := minInterimPerNode + i%maxInterimPerNode + 2
		eas = append(eas, endpointAcct{
			mac:                fmt.Sprintf("%x", startMac+i),
			ip:                 int2ip(uint32(startIp + i)),
			inBytesPerSession:  startInBytes + i,
			outBytesPerSession: startOutBytes + i,
			sessionCount:       sessionCount,
		})
	}

	runEndpointAccts(eas)
	atomic.AddUint64(&loadedChans, 1)
}

func sendAccountingPacket(pi pktinfo) {
	t := pi.t
	mac := pi.mac
	ip := pi.ip
	inBytes := pi.inBytes
	outBytes := pi.outBytes
	sessionTime := pi.sessionTime

	fmt.Printf("Send accounting (%d): ip:%s, mac:%s, inbytes:%d, outbytes:%d, time:%d \n", t, ip, mac, inBytes, outBytes, sessionTime)

	p := radius.New(radius.CodeAccountingRequest, []byte(*secret))
	rfc2866.AcctStatusType_Add(p, t)
	rfc2866.AcctSessionID_AddString(p, *sessionIdPrefix+mac)
	rfc2866.AcctInputOctets_Add(p, rfc2866.AcctInputOctets(inBytes))
	rfc2866.AcctOutputOctets_Add(p, rfc2866.AcctOutputOctets(outBytes))
	rfc2866.AcctSessionTime_Add(p, rfc2866.AcctSessionTime(sessionTime))
	rfc2865.UserName_AddString(p, "UserOF-"+mac)
	rfc2865.CalledStationID_AddString(p, *calledStationId)
	rfc2865.FramedIPAddress_Add(p, ip)
	rfc2865.NASPort_Add(p, rfc2865.NASPort(*nasPort))
	rfc2865.CallingStationID_AddString(p, mac)
	rfc2865.NASIPAddress_Add(p, net.ParseIP(*nasIpAddress))
	rfc2869.EventTimestamp_Add(p, time.Now())

	client := &radius.Client{}
	// Use the background context since we don't want the lib to use our context
	ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(1*time.Second))
	defer cancel()
	_, err := client.Exchange(ctx, p, *host+":"+*port)
	if err != nil {
		fmt.Printf("%s: Couldn't sent the RADIUS packet due to: %s \n", time.Now(), err)
	}
}

func runEndpointAccts(eas []endpointAcct) {
	maxSessionCount := 0
	for _, ea := range eas {
		if ea.sessionCount > maxSessionCount {
			maxSessionCount = ea.sessionCount
		}
	}

	fmt.Printf("Will run the loop %d times\n", maxSessionCount)

	for i := 1; i <= maxSessionCount; i++ {
		for _, ea := range eas {
			var t rfc2866.AcctStatusType
			if i == 1 {
				t = rfc2866.AcctStatusType_Value_Start
			} else if i < ea.sessionCount {
				t = rfc2866.AcctStatusType_Value_InterimUpdate
			} else if i == ea.sessionCount {
				t = rfc2866.AcctStatusType_Value_Stop
			} else {
				continue
			}
			inBytes := i * ea.inBytesPerSession
			outBytes := i * ea.outBytesPerSession
			//fmt.Printf("Send accounting %s (%d): ip:%s, mac:%s, inbytes:%d, outbytes:%d, time:%d \n", strt, t, ea.ip, ea.mac, inBytes, outBytes, i)
			pi := pktinfo{t: t, mac: ea.mac, ip: ea.ip, inBytes: inBytes, outBytes: outBytes, sessionTime: i}

			workChans[int(ea.ip[3])%*concurrency] <- pi
		}
	}
}

func runWorkers() {
	wg.Add(1)
	defer wg.Done()

	for i := 0; i < *concurrency; i++ {
		workChans[i] = make(chan pktinfo, 100)
		wg.Add(1)
		go func(i int) {
			// Sleep a bit to give time to jobs to populate
			time.Sleep(1 * time.Second)
			for {
				select {
				case pkt := <-workChans[i]:
					sendAccountingPacket(pkt)
				default:
					if atomic.LoadUint64(&loadedChans) != 0 {
						fmt.Println("Worker", i, "is done")
						wg.Done()
						return
					} else {
						fmt.Println("Worker", i, "is done but more jobs are coming. Will wait.")
						time.Sleep(100 * time.Millisecond)
					}
				}
			}
		}(i)
	}
}

func main() {
	flag.Parse()
	workChans = make([]chan pktinfo, *concurrency)
	runWorkers()
	loadTest(*nodesCount, *minInterimPerNode, *maxInterimPerNode)

	wg.Wait()
}
