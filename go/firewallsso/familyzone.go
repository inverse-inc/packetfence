package firewallsso

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/log"
)

type FamilyZone struct {
	FirewallSSO
	Username string `json:"username"`
	Password string `json:"password"`
	Port     string `json:"port"`
	Region   string `json:"region"`
}

// Firewall specific init
func (fw *FamilyZone) initChild(ctx context.Context) error {
	// Set a default value for vsys if there is none
	if fw.Region == "" {
		log.LoggerWContext(ctx).Debug("Setting default value for Region as it isn't defined")
		fw.Region = "syd-1"
	}
	return nil
}

// Send an SSO start to the FamilyZone using HTTP
func (fw *FamilyZone) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO to FamilyZone using HTTP")
	return fw.startHttp(ctx, info, timeout)
}

// Send a start to the FamilyZone using the HTTP transport
// Will return an error if it fails to get a valid reply from it
func (fw *FamilyZone) startHttp(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	id, err := uuid.NewUUID()
	if err != nil {
		log.LoggerWContext(ctx).Info("Oups too bad")
	}
	s := fw.Password + "__" + info["username"] + "_PacketFence_" + id.String()
	h := sha1.New()
	h.Write([]byte(s))
	sha1_hash := hex.EncodeToString(h.Sum(nil))
	resp, err := fw.getHttpClient(ctx).Get("https://login." + fw.Region + ".linewize.net/login/agent?deviceid=" + info["computername"] + "&mac=" + info["mac"] + "&ip=" + info["ip"] + "&username=" + info["username"] + "&agent=PacketFence&hash=" + sha1_hash + "&salt=" + id.String())

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting FamilyZone: %s", err))
		//Not returning now so that body closes below
	}

	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}

	return err == nil, err
}

// Send an SSO stop to the firewall if the transport mode is HTTP. Otherwise, this outputs a warning
// Will return the values from stopHttp for HTTP and no error if its syslog
func (fw *FamilyZone) Stop(ctx context.Context, info map[string]string) (bool, error) {
	log.LoggerWContext(ctx).Info("Not supported sending SSO to FamilyZone using HTTP")
	return true, nil
}
