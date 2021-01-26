package main

import (
	"context"
	"fmt"
	"net"
	"os"
	"sync"
	"time"

	"github.com/inverse-inc/packetfence/go/galeraautofix/mariadb"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	ping "github.com/sparrc/go-ping"
)

type NodeList struct {
	sync.RWMutex
	Nodes []*Node
}

func NewNodeList() *NodeList {
	return &NodeList{
		RWMutex: sync.RWMutex{},
		Nodes:   []*Node{},
	}
}

func (nl *NodeList) AddNode(node *Node) {
	nl.Lock()
	defer nl.Unlock()
	nl.Nodes = append(nl.Nodes, node)
}

type NodeStats struct {
	Pingable    bool
	DBAvailable bool
}

type Node struct {
	IP       net.IP
	Hostname string
	Seqno    int
	Stats    NodeStats
}

func NewNode(ip net.IP, hostname string) *Node {
	return &Node{
		IP:       ip,
		Hostname: hostname,
		Seqno:    mariadb.DefaultSeqno,
		Stats:    NodeStats{},
	}
}

func (n *Node) RefreshStats(ctx context.Context) {
	n.Stats.Pingable = n.IsPingable(ctx)
	n.Stats.DBAvailable = n.IsDBAvailable(ctx)
}

func (n *Node) IsPingable(ctx context.Context) bool {
	pinger, err := ping.NewPinger(n.IP.String())
	if err != nil {
		log.LoggerWContext(ctx).Error("Unable to create pinger for " + n.IP.String() + ": " + err.Error())
		return false
	}

	pinger.SetPrivileged(true)
	pinger.Count = 4
	pinger.Timeout = 10 * time.Second
	pinger.Run()
	if ploss := pinger.Statistics().PacketLoss; ploss > 0 {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("Node %s is not pingable. Packet loss of %f%%.", n.IP.String(), ploss))
		return false
	} else {
		return true
	}
}

func (n *Node) IsDBAvailable(ctx context.Context) bool {
	return mariadb.IsDBAvailable(ctx, n.IP.String())
}

func (n *Node) IsThisServer(ctx context.Context) bool {
	hostname, err := os.Hostname()
	sharedutils.CheckError(err)
	return hostname == n.Hostname
}

func (n *Node) IsDisabled(ctx context.Context) bool {
	_, err := os.Stat(fmt.Sprintf("/usr/local/pf/var/run/%s-cluster-disabled", n.Hostname))
	return err == nil
}
