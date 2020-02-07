package main

import (
	"context"
	"fmt"
	"net"
	"time"

	"github.com/inverse-inc/packetfence/go/galeraautofix/mariadb"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func main() {
	ctx := context.Background()
	go seqnoReporting(ctx)

	decisionLoop(ctx)
}

func seqnoReporting(ctx context.Context) {
	servers := pfconfigdriver.AllClusterServers{}
	for {
		seqNo := mariadb.DefaultSeqno
		if mariadb.IsLocalDBAvailable(ctx) {
			log.LoggerWContext(ctx).Info("Database is currently running on this node, the sequence number is implicitely set to -1")
			seqNo = mariadb.RunningSeqno
		} else {
			mariadb.WsrepRecover(ctx)
			var err error
			seqNo, err = mariadb.GetSeqno(ctx)
			if err != nil {
				log.LoggerWContext(ctx).Error("Unable to obtain sequence number")
				return
			}
		}

		pfconfigdriver.FetchDecodeSocketCache(ctx, &servers)
		for _, server := range servers.Element {
			conn, err := net.Dial("udp", server.ManagementIp+":4253")
			if err != nil {
				log.LoggerWContext(ctx).Warn("Unable to dial " + server.ManagementIp + ": " + err.Error())
			}
			log.LoggerWContext(ctx).Debug("Reported sequence number to " + server.ManagementIp)
			sendMessage(ctx, conn, MSG_SET_SEQNO, seqNo)
		}
		time.Sleep(1 * time.Second)
	}
}

func decisionLoop(ctx context.Context) {
	for {
		servers := pfconfigdriver.AllClusterServers{}
		pfconfigdriver.FetchDecodeSocketCache(ctx, &servers)
		nodes := NewNodeList()
		for _, server := range servers.Element {
			node := NewNode(net.ParseIP(server.ManagementIp), server.Host)
			node.RefreshStats(ctx)
			nodes.AddNode(node)
		}
		handle(ctx, nodes)
		time.Sleep(1 * time.Second)
	}
}

func handle(ctx context.Context, nodes *NodeList) {
	if mariadb.IsLocalDBAvailable(ctx) {
		log.LoggerWContext(ctx).Info("Local DB is available, nothing to do")
		return
	}

	if len(nodes.Nodes) == 0 {
		log.LoggerWContext(ctx).Info("No cluster peers found. Not doing anything.")
		return
	}

	if handlePeerDBAvailable(ctx, nodes) {
		log.LoggerWContext(ctx).Info("The DB available workflow has been used for this iteration")
		return
	}

	if handlePeersPingable(ctx, nodes) {
		log.LoggerWContext(ctx).Info("The peers pingable workflow has been used for this iteration")
		return
	}

	log.LoggerWContext(ctx).Warn("Unable to use any strategy to startup the database and join it to the rest of the cluster.")
}

func handlePeersPingable(ctx context.Context, nodes *NodeList) bool {
	peers := filterPeers(ctx, nodes)
	for _, node := range peers {
		if !node.Stats.Pingable {
			log.LoggerWContext(ctx).Warn(fmt.Sprintf("Peer %s is not online currently. Will not attempt to perform sequence number based boot"))
			return false
		}
	}

	waitUntil := time.Now().Add(2 * time.Minute)
	for {
		if time.Now().After(waitUntil) {
			log.LoggerWContext(ctx).Warn("Waited too long for peers to report their sequence number.")
			return false
		}

		allReported := true
		for _, node := range nodes.Nodes {
			if node.Seqno == mariadb.DefaultSeqno {
				allReported = false
			}
		}

		if allReported {
			break
		}
	}

	highestSeqnoNode := nodes.Nodes[0]
	for _, node := range nodes.Nodes {
		if node.Seqno == mariadb.DefaultSeqno {
			log.LoggerWContext(ctx).Warn(fmt.Sprintf("Node %s hasn't reported its status. Cannot perform boot based on sequence number", node.IP.String()))
		} else if node.Seqno == mariadb.RunningSeqno {
			log.LoggerWContext(ctx).Warn(fmt.Sprintf("Node %s is actively running. Stopping the sequence number boot process since the DB available process should be used.", node.IP.String()))
			return false
		}
		log.LoggerWContext(ctx).Info(fmt.Sprintf("Node %s has a sequence number of %d", node.IP.String(), node.Seqno))
		if node.Seqno > highestSeqnoNode.Seqno {
			highestSeqnoNode = node
		}
	}

	log.LoggerWContext(ctx).Info(fmt.Sprintf("Node %s has the highest sequence number: %d", highestSeqnoNode.IP.String(), highestSeqnoNode.Seqno))
	if highestSeqnoNode.IsThisServer(ctx) {
		log.LoggerWContext(ctx).Info("This node should be bootstraping based off the sequence number and the node ordering in cluster.conf. Starting in --force-new-cluster mode")
		bootNewCluster(ctx)
	} else {
		log.LoggerWContext(ctx).Info("This node is not the one that was selected for bootstraping. Will have to wait until the DB becomes available to connect to it")
	}

	return true
}

func handlePeerDBAvailable(ctx context.Context, nodes *NodeList) bool {
	peers := filterPeers(ctx, nodes)
	for _, node := range peers {
		if node.Stats.DBAvailable {
			log.LoggerWContext(ctx).Info("Database is available on " + node.IP.String() + ". Starting clean and boot process.")
			bootAndRejoinCluster(ctx)
			return true
		}
	}

	log.LoggerWContext(ctx).Warn("Database is unavailable on all the hosts of the cluster")
	return false
}

func filterPeers(ctx context.Context, nodes *NodeList) []Node {
	peers := []Node{}
	for _, node := range nodes.Nodes {
		if !node.IsThisServer(ctx) {
			peers = append(peers, node)
		}
	}

	return peers
}

func bootAndRejoinCluster(ctx context.Context) {
	if mariadb.IsActive(ctx) {
		mariadb.ClearAndStart(ctx)
	} else {
		log.LoggerWContext(ctx).Warn("MariaDB service is inactive. System can be in maintenance or service may have explicitely been disabled. Not performing any operation to rejoin the cluster.")
	}
}

func bootNewCluster(ctx context.Context) {
	if mariadb.IsActive(ctx) {
		mariadb.StartNewCluster(ctx)
	} else {
		log.LoggerWContext(ctx).Warn("MariaDB service is inactive. System can be in maintenance or service may have explicitely been disabled. Not performing any operation to start a new cluster.")
	}
}
