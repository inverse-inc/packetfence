package firewallsso

import (
	"context"
	"fmt"
	"github.com/inverse-inc/go-utils/log"
	"golang.org/x/crypto/ssh"
)

type BarracudaNG struct {
	FirewallSSO
	Username string `json:"username"`
	Password string `json:"password"`
	Port     string `json:"port"`
}

// Get an SSH session to the firewall
func (fw *BarracudaNG) getSshSession(ctx context.Context) (*ssh.Session, error) {
	sshConfig := &ssh.ClientConfig{
		User: fw.Username,
		Auth: []ssh.AuthMethod{
			ssh.Password(fw.Password),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
	}
	connection, err := ssh.Dial("tcp", fw.PfconfigHashNS+":"+fw.Port, sshConfig)

	if err != nil {
		return nil, err
	}

	session, err := connection.NewSession()

	return session, err
}

// Send an SSO start to the BarracudaNG Firewall
// Will return an error if it can't connect
func (fw *BarracudaNG) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	session, err := fw.getSshSession(ctx)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Cannot connect to BarracudaNG: %s", err))
		return false, err
	}

	cmd := "phibstest 127.0.0.1 l peer=" + info["ip"] + " origin=PacketFence service=PacketFence user=" + info["username"]
	session.Run(cmd)

	return true, nil
}

// Send an SSO stop to the BarracudaNG Firewall
// Will return an error if it can't connect
func (fw *BarracudaNG) Stop(ctx context.Context, info map[string]string) (bool, error) {
	session, err := fw.getSshSession(ctx)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Cannot connect to BarracudaNG: %s", err))
		return false, err
	}

	cmd := "phibstest 127.0.0.1 o peer=" + info["ip"] + " origin=PacketFence service=PacketFence user=" + info["username"]
	session.Run(cmd)

	return true, nil
}
