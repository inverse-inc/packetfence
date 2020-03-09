package main

import (
	"context"
	"encoding/binary"
	"flag"
	"fmt"
	"net"
	"time"

	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
	"layeh.com/radius/rfc2866"
)

var host = flag.String("host", "127.0.0.1", "The host to send the packets to")
var port = flag.String("port", "1813", "The port to send the packets to")
var secret = flag.String("secret", "secret", "The RADIUS secret to use")
var calledStationId = flag.String("called-station-id", "02:00:00:00:00:01", "The Called-Station-Id to use")

var nodesCount = flag.Int("lt-nodes-count", 1, "The amount of nodes to use while load-testing")
var minInterimPerNode = flag.Int("lt-min-interim-per-node", 0, "The minimal amount of interim updates per node while load-testing")
var maxInterimPerNode = flag.Int("lt-max-interim-per-node", 20, "The minimal amount of interim updates per node while load-testing")

var sessionIdPrefix = flag.String("session-id-prefix", "acct-tester-", "The prefix of the session IDs")

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
}

func sendAccountingPacket(t rfc2866.AcctStatusType, mac string, ip net.IP, inBytes int, outBytes int, sessionTime int) {
	p := radius.New(radius.CodeAccountingRequest, []byte(*secret))
	rfc2866.AcctStatusType_Add(p, t)
	rfc2866.AcctSessionID_AddString(p, *sessionIdPrefix+mac)
	rfc2866.AcctInputOctets_Add(p, rfc2866.AcctInputOctets(inBytes))
	rfc2866.AcctOutputOctets_Add(p, rfc2866.AcctOutputOctets(outBytes))
	rfc2866.AcctSessionTime_Add(p, rfc2866.AcctSessionTime(sessionTime))
	rfc2865.UserName_AddString(p, "UserOF-"+mac)
	rfc2865.CalledStationID_AddString(p, *calledStationId)
	rfc2865.FramedIPAddress_Add(p, ip)
	rfc2865.CallingStationID_AddString(p, mac)

	client := &radius.Client{}
	// Use the background context since we don't want the lib to use our context
	ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(5*time.Second))
	defer cancel()
	_, err := client.Exchange(ctx, p, *host+":"+*port)
	if err != nil {
		fmt.Printf("Couldn't sent the RADIUS packet due to: %s \n", err)
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
			var strt string
			if i == 1 {
				t = rfc2866.AcctStatusType_Value_Start
				strt = "Start"
			} else if i < ea.sessionCount {
				t = rfc2866.AcctStatusType_Value_InterimUpdate
				strt = "Interim-Update"
			} else if i == ea.sessionCount {
				t = rfc2866.AcctStatusType_Value_Stop
				strt = "Stop"
			} else {
				continue
			}
			inBytes := i * ea.inBytesPerSession
			outBytes := i * ea.outBytesPerSession
			fmt.Printf("Send accounting %s (%d): ip:%s, mac:%s, inbytes:%d, outbytes:%d, time:%d \n", strt, t, ea.ip, ea.mac, inBytes, outBytes, i)
			sendAccountingPacket(t, ea.mac, ea.ip, inBytes, outBytes, i)
		}
	}
}

func main() {
	flag.Parse()
	loadTest(*nodesCount, *minInterimPerNode, *maxInterimPerNode)
}
