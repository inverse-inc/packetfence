package common

import (
	"context"
	"fmt"
	"net"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

func IP2MAC(ctx context.Context, ip net.IP) (string, error) {
	var apiClient = unifiedapiclient.NewFromConfig(context.Background())
	foundMac := unifiedapiclient.Ip2MacResponse{}
	err := apiClient.Call(ctx, "GET", "/api/v1/ip4logs/ip2mac/"+ip.String(), &foundMac)
	if err != nil {
		msg := fmt.Sprintf("Problem getting the mac for ip '%s': %s", ip, err)
		log.LoggerWContext(ctx).Error(msg)
		return "", fmt.Errorf("%s", msg)
	}

	return foundMac.Mac, nil
}
