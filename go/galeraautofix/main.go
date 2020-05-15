package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"net"
	"time"

	"github.com/inverse-inc/packetfence/go/galeraautofix/mariadb"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

const (
	startWait                    = time.Duration(10 * time.Minute)
	decisionLoopInterval         = time.Duration(1 * time.Minute)
	seqnoReportingTimeout        = time.Duration(1 * time.Minute)
	seqnoReportingInterval       = time.Duration(10 * time.Second)
	dbAvailableDetectionCooldown = time.Duration(1 * time.Minute)
	bootAndRejoinClusterTimeout  = time.Duration(1 * time.Minute)

	ChitChatPort = 4253
)

func main() {
	ctx := context.Background()
	ctx = log.LoggerNewContext(ctx)
	go seqnoReporting(ctx)

	log.LoggerWContext(ctx).Info(fmt.Sprintf("Waiting %s before we start checking for DB issues", startWait))
	time.Sleep(startWait)
	log.LoggerWContext(ctx).Info("Activating galera-autofix")

	decisionLoop(ctx)
}

func getSeqnoReport(ctx context.Context, nodes *NodeList) bool {
	log.LoggerWContext(ctx).Info("Started server to listen to sequence numbers from peers")
	sAddr, err := net.ResolveUDPAddr("udp", fmt.Sprintf(":%d", ChitChatPort))
	sharedutils.CheckError(err)
	serv, err := net.ListenUDP("udp", sAddr)
	defer serv.Close()

	waitUntil := time.Now().Add(seqnoReportingTimeout)
	serv.SetDeadline(waitUntil)

	for {
		if time.Now().After(waitUntil) {
			log.LoggerWContext(ctx).Warn("Waited too long for peers to report their sequence number.")
			return false
		}

		buf := make([]byte, 1024)
		n, addr, err := serv.ReadFromUDP(buf)
		if err != nil {
			continue
		}
		handleMessage(ctx, addr.IP, buf[:n], nodes)

		allReported := true
		for _, node := range nodes.Nodes {
			if node.Seqno == mariadb.DefaultSeqno {
				allReported = false
			}
		}

		if allReported {
			return true
		}
	}
}

func getRecordLiveSeqno(ctx context.Context) int {
	seqno := mariadb.GetLocalLiveSeqno(ctx)
	if seqno != mariadb.DefaultSeqno {
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Found the following live sequence number: %d", seqno))
		err := ioutil.WriteFile(mariadb.GaleraAutofixSeqnoFile, []byte(fmt.Sprintf("%d", seqno)), 0644)
		sharedutils.CheckError(err)
	} else {
		log.LoggerWContext(ctx).Debug("Failed to obtain the live sequence number")
	}
	return seqno
}

func seqnoReporting(ctx context.Context) {
	servers := pfconfigdriver.AllClusterServers{}
	for {
		seqno := mariadb.DefaultSeqno
		if mariadb.IsLocalDBAvailable(ctx) {
			seqno = getRecordLiveSeqno(ctx)
		} else {
			var err error
			seqno, err = mariadb.GetColdSeqno(ctx)
			if err != nil {
				log.LoggerWContext(ctx).Error("Unable to obtain sequence number")
				time.Sleep(seqnoReportingInterval)
				continue
			}
		}

		pfconfigdriver.FetchDecodeSocketCache(ctx, &servers)
		for _, server := range servers.Element {
			conn, err := net.Dial("udp", fmt.Sprintf("%s:%d", server.ManagementIp, ChitChatPort))
			if err != nil {
				log.LoggerWContext(ctx).Warn("Unable to dial " + server.ManagementIp + ": " + err.Error())
			}
			log.LoggerWContext(ctx).Debug(fmt.Sprintf("Reported sequence number %d to %s", seqno, server.ManagementIp))
			sendMessage(ctx, conn, MSG_SET_SEQNO, seqno)
			conn.Close()
		}
		time.Sleep(seqnoReportingInterval)
	}
}

func decisionLoop(ctx context.Context) {
	servers := pfconfigdriver.AllClusterServers{}
	for {
		pfconfigdriver.FetchDecodeSocketCache(ctx, &servers)
		nodes := NewNodeList()
		for _, server := range servers.Element {
			node := NewNode(net.ParseIP(server.ManagementIp), server.Host)
			node.RefreshStats(ctx)
			nodes.AddNode(node)
		}
		handle(ctx, nodes)
		time.Sleep(decisionLoopInterval)
	}
}

func handle(ctx context.Context, nodes *NodeList) {
	if mariadb.IsLocalDBAvailable(ctx) {
		log.LoggerWContext(ctx).Info("Local DB is available, nothing to do")
		return
	}

	if len(nodes.Nodes) <= 1 {
		log.LoggerWContext(ctx).Info("No cluster peers found. Not doing anything.")
		return
	}

	for _, n := range nodes.Nodes {
		if n.IsDisabled(ctx) {
			log.LoggerWContext(ctx).Info("At least one of the cluster nodes is disabled. Not doing anything.")
			return
		}
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
			log.LoggerWContext(ctx).Warn(fmt.Sprintf("Peer %s is not online currently. Will not attempt to perform sequence number based boot", node.IP.String()))
			return false
		}
	}

	if !getSeqnoReport(ctx, nodes) {
		log.LoggerWContext(ctx).Warn("Unable to obtain sequence number from all the cluster members")
		return false
	}

	highestSeqnoNode := nodes.Nodes[0]
	for _, node := range nodes.Nodes {
		if node.Seqno == mariadb.DefaultSeqno {
			log.LoggerWContext(ctx).Warn(fmt.Sprintf("Node %s hasn't reported its status. Cannot perform boot based on sequence number", node.IP.String()))
			return false
		}
		log.LoggerWContext(ctx).Info(fmt.Sprintf("Node %s has a sequence number of %d", node.IP.String(), node.Seqno))
		if node.Seqno > highestSeqnoNode.Seqno {
			highestSeqnoNode = node
		}
	}

	if highestSeqnoNode.Seqno == mariadb.RunningSeqno {
		log.LoggerWContext(ctx).Warn("Failed to obtain a valid sequence number to determine best bootable node. Cannot use this strategy to boot: " + highestSeqnoNode.IP.String())
		return false
	}

	log.LoggerWContext(ctx).Info(fmt.Sprintf("Node %s has the highest sequence number: %d", highestSeqnoNode.IP.String(), highestSeqnoNode.Seqno))
	if highestSeqnoNode.IsThisServer(ctx) {
		log.LoggerWContext(ctx).Info("This node should be bootstraping based off the sequence number and the node ordering in cluster.conf. Starting in --force-new-cluster mode")
		bootNewCluster(ctx)
	} else {
		log.LoggerWContext(ctx).Info("This node is not the one that was selected for bootstraping. Starting bootAndRejoinCluster")
		bootAndRejoinCluster(ctx, highestSeqnoNode)
	}

	return true
}

func handlePeerDBAvailable(ctx context.Context, nodes *NodeList) bool {
	peers := filterPeers(ctx, nodes)
	for _, node := range peers {
		if node.Stats.DBAvailable {
			log.LoggerWContext(ctx).Info("Found a peer DB available. Cooling down for a minute to see if the DB on this server will become ready before attempting to rejoin cluster by force.")
			// Wait a minute to see if the local DB becomes availble before clearing data and restarting from scratch
			time.Sleep(dbAvailableDetectionCooldown)
			if mariadb.IsLocalDBAvailable(ctx) {
				log.LoggerWContext(ctx).Info("Database became available on this server. Skipping forced rejoin.")
				return true
			}

			log.LoggerWContext(ctx).Info("Database is available on " + node.IP.String() + ". Starting bootAndRejoinCluster.")
			bootAndRejoinCluster(ctx, node)
			return true
		}
	}

	log.LoggerWContext(ctx).Warn("Database is unavailable on all the hosts of the cluster")
	return false
}

func filterPeers(ctx context.Context, nodes *NodeList) []*Node {
	peers := []*Node{}
	for _, node := range nodes.Nodes {
		if !node.IsThisServer(ctx) {
			peers = append(peers, node)
		}
	}

	return peers
}

func bootAndRejoinCluster(ctx context.Context, node *Node) {
	if mariadb.IsActive(ctx) {
		mariadb.ForceStop(ctx)

		waitUntil := time.Now().Add(bootAndRejoinClusterTimeout)
		for {
			if time.Now().After(waitUntil) {
				log.LoggerWContext(ctx).Error(fmt.Sprintf("Waited too long for %s to offer DB service.", node.IP.String()))
				// Start it again so the service stays active
				mariadb.Start(ctx)
				return
			}

			if node.IsDBAvailable(ctx) {
				log.LoggerWContext(ctx).Info(fmt.Sprintf("Database on %s is ready. Clearing own data and starting DB.", node.IP.String()))
				break
			} else {
				log.LoggerWContext(ctx).Debug(fmt.Sprintf("Database on %s is not ready yet. Waiting until its ready to start booting this node", node.IP.String()))
			}

			time.Sleep(1 * time.Second)
		}

		mariadb.ClearAndStart(ctx)
	} else {
		log.LoggerWContext(ctx).Warn("MariaDB service is inactive. System can be in maintenance or service may have explicitely been disabled. Not performing any operation to rejoin the cluster.")
	}
}

func bootNewCluster(ctx context.Context) {
	if mariadb.IsActive(ctx) {
		mariadb.ForceStop(ctx)
		mariadb.StartNewCluster(ctx)
	} else {
		log.LoggerWContext(ctx).Warn("MariaDB service is inactive. System can be in maintenance or service may have explicitely been disabled. Not performing any operation to start a new cluster.")
	}
}
