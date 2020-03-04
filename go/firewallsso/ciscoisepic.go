package firewallsso

import (
	"context"
	"fmt"
	"log/syslog"

	"github.com/inverse-inc/packetfence/go/log"
)

type CiscoIsePic struct {
	FirewallSSO
	Port string `json:"port"`
}

func (fw *CiscoIsePic) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO to CiscoIsePic using syslog")
	return fw.startSyslog(ctx, info, timeout)
}

func (fw *CiscoIsePic) getSyslog(ctx context.Context) (*syslog.Writer, error) {
	writer, err := syslog.Dial("udp", fmt.Sprintf("%s:%s", fw.PfconfigHashNS, fw.Port), syslog.LOG_ERR|syslog.LOG_LOCAL5, "pfsso")

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error connecting to CiscoIsePic: %s", err))
		return nil, err
	}

	return writer, err
}

func (fw *CiscoIsePic) sendSyslog(ctx context.Context, line string) error {
	writer, err := fw.getSyslog(ctx)

	if err != nil {
		return err
	}

	err = writer.Err(line)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error sending message to CiscoIsePic: %s", err))
		return err
	}

	return nil
}

func (fw *CiscoIsePic) startSyslog(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	if err := fw.sendSyslog(ctx, fmt.Sprintf("Group <packetfence> User <%s> Address <%s> assigned to session", info["username"], info["ip"])); err != nil {
		return false, err
	} else {
		return true, nil
	}
}

func (fw *CiscoIsePic) Stop(ctx context.Context, info map[string]string) (bool, error) {
	log.LoggerWContext(ctx).Warn("SSO Stop isn't supported on Cisco ISE-PIC.")
	return false, nil
}
