package tunnel

import (
	"crypto/hmac"
	"crypto/md5"

	"github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/rfc2869"
	"github.com/inverse-inc/go-utils/sharedutils"
)

func proxyRadiusOut(h *udpHandler, b []byte) ([]byte, error) {
	//TODO: find the secret using the following logic
	// 1. Check if Called-Station-Id has an entry in radius_nas, if yes use this secret
	// 2. Check if NAS-IP-Address has an entry in radius_nas, if yes use this secret
	// 3. Use the secret in conf/local_secret
	p, err := radius.Parse(b, []byte("MWZjMzc1YmYyYjhiOWZjYjAwYzEzZDBm"))

	//TODO: Switch from panicking on errors to returning the errors and handling them correctly in tunnel_out_ssh_udp
	//TODO: Stop using hardcoded numbers and switch to constants
	connectorAttr, err := radius.NewString(h.connectorID)
	sharedutils.CheckError(err)
	vendorConnectorAttr := make(radius.Attribute, 2+len(connectorAttr))
	vendorConnectorAttr[0] = 40
	vendorConnectorAttr[1] = byte(len(vendorConnectorAttr))
	copy(vendorConnectorAttr[2:], connectorAttr)

	vsa, err := radius.NewVendorSpecific(29464, vendorConnectorAttr)
	sharedutils.CheckError(err)
	p.Attributes.Add(26, vsa)

	// Remove any existing message authenticator and set it correctly
	p.Attributes.Del(80)

	hash := hmac.New(md5.New, []byte("MWZjMzc1YmYyYjhiOWZjYjAwYzEzZDBm"))

	rfc2869.MessageAuthenticator_Set(p, []byte{0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0})
	encode, _ := p.Encode()
	hash.Write(encode)
	rfc2869.MessageAuthenticator_Set(p, hash.Sum(nil))

	b2, err := p.Encode()
	sharedutils.CheckError(err)
	return b2, nil
}

func proxyRadiusIn(h *udpHandler, b []byte) ([]byte, error) {
	//TODO: sign the packet with the RADIUS secret that was used in proxyRadiusOut
	return b, nil
}
