package pfipset

import (
	"context"
	"io"
	"io/ioutil"
	"net"
	"net/http"
	"regexp"
	"strconv"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

var body io.Reader

type pfIPSET struct {
	jobs chan job
}

func pfIPSETFromContext(ctx context.Context) *pfIPSET {
	return ctx.Value("IPSET").(*pfIPSET)
}

func (IPSET *pfIPSET) AddToContext(ctx context.Context) context.Context {
	return context.WithValue(ctx, "IPSET", IPSET)
}

// Detect the vip on each interfaces
func getClusterMembersIps(ctx context.Context) []net.IP {
	hostsIp := pfconfigdriver.GetStruct(ctx, "HostsIp").(*pfconfigdriver.HostsIp)

	var members []net.IP
	for _, key := range hostsIp.Keys {
		var ConfNet pfconfigdriver.PfClusterIp
		ConfNet.PfconfigHashNS = key

		pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)

		IP := net.ParseIP(ConfNet.Ip)
		var present bool

		ifaces, _ := net.Interfaces()
		for _, netInterface := range ifaces {
			addrs, _ := netInterface.Addrs()
			for _, UnicastAddr := range addrs {
				IPE, _, _ := net.ParseCIDR(UnicastAddr.String())
				if IP.Equal(IPE) {
					present = true
				}
			}
		}
		if present == false {
			members = append(members, IP)
		}
	}
	return members
}

func updateClusterRequest(ctx context.Context, origReq *http.Request) {
	logger := log.LoggerWContext(ctx)

	Local := origReq.URL.Query().Get("local")
	if Local != "0" {
		return
	}

	req, err := sharedutils.CopyHttpRequest(origReq)
	sharedutils.CheckError(err)

	logger.Info("Syncing to peers")

	apiClient := unifiedapiclient.NewFromConfig(context.Background())
	body, err := ioutil.ReadAll(req.Body)
	sharedutils.CheckError(err)

	for _, member := range getClusterMembersIps(ctx) {
		apiClient.Host = member.String()

		err := apiClient.CallWithStringBody(ctx, req.Method, req.URL.Path+"?local=1", string(body), &unifiedapiclient.DummyReply{})
		if err != nil {
			logger.Error("Not able to contact " + member.String() + err.Error())
		} else {
			logger.Info("Updated " + member.String())
		}
	}
}

func validatePort(portSpec string) (uint16, byte, bool) {
	re := regexp.MustCompile("(udp|tcp):([0-9]+)")
	matches := re.FindStringSubmatch(portSpec)
	if matches == nil {
		return 0, 0, false
	}
	var proto byte
	switch matches[1] {
	case "tcp":
		proto = 6
	case "udp":
		proto = 17
	}

	port, _ := strconv.ParseUint(matches[2], 10, 16)
	return uint16(port), proto, true
}
