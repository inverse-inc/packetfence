package models

import (
	"context"
	"math/big"
	"strings"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
	"golang.org/x/crypto/ocsp"
)

// nodeTLS is the part of the node_tls table (filled from the RADIUS audit log
// on every EAP-TLS authentication) needed to find the devices that used a
// certificate.
type nodeTLS struct {
	Mac                 string `gorm:"column:mac"`
	TLSClientCertSerial string `gorm:"column:TLSClientCertSerial"`
	TLSClientCertIssuer string `gorm:"column:TLSClientCertIssuer"`
}

// deregisterNodes deregisters the nodes and re-evaluates their access so the
// switch drops the session. A variable so tests can replace it. The pf::api
// functions take their arguments as a flat list of name/value pairs.
var deregisterNodes = func(ctx context.Context, macs []string, cn string) {
	client := jsonrpc2.NewClientFromConfig(ctx)
	for _, mac := range macs {
		if _, err := client.Call(ctx, "deregister_node", []interface{}{"mac", mac}); err != nil {
			log.LoggerWContext(ctx).Error("Unable to deregister node " + mac + " of revoked certificate " + cn + ": " + err.Error())
			continue
		}
		if _, err := client.Call(ctx, "reevaluate_access", []interface{}{"mac", mac, "reason", "pki_certificate_revoked"}); err != nil {
			log.LoggerWContext(ctx).Error("Unable to reevaluate access of node " + mac + ": " + err.Error())
		}
		log.LoggerWContext(ctx).Info("Node " + mac + " deregistered: its certificate " + cn + " has been revoked")
	}
}

// serialsMatch compares the serial FreeRADIUS reports (hexadecimal, as stored
// in node_tls) with the serial pfpki stores (decimal).
func serialsMatch(nodeSerial, pkiSerial string) bool {
	hex := strings.NewReplacer(":", "", " ", "").Replace(strings.TrimSpace(nodeSerial))
	hex = strings.TrimPrefix(strings.TrimPrefix(hex, "0x"), "0X")
	if hex == "" || strings.EqualFold(hex, "N/A") {
		return false
	}
	n, ok := new(big.Int).SetString(hex, 16)
	if !ok {
		return false
	}
	p, ok := new(big.Int).SetString(strings.TrimSpace(pkiSerial), 10)
	if !ok {
		return false
	}
	return n.Cmp(p) == 0
}

// issuerHasCN tells if the issuer DN FreeRADIUS reports (/C=CA/.../CN=MyCA,
// with the slashes escaped in node_tls) has caCN as common name.
func issuerHasCN(issuer, caCN string) bool {
	if caCN == "" {
		return false
	}
	issuer = strings.ReplaceAll(issuer, `\`, "")
	for _, rdn := range strings.FieldsFunc(issuer, func(r rune) bool { return r == '/' || r == ',' }) {
		if strings.TrimSpace(rdn) == "CN="+caCN {
			return true
		}
	}
	return false
}

// macsOfCert returns the devices whose last EAP-TLS authentication used cert.
func macsOfCert(rows []nodeTLS, cert Cert) []string {
	var macs []string
	for _, row := range rows {
		if serialsMatch(row.TLSClientCertSerial, cert.SerialNumber) && issuerHasCN(row.TLSClientCertIssuer, cert.CaName) {
			macs = append(macs, row.Mac)
		}
	}
	return macs
}

// shouldDeregisterOnRevocation: a superseded certificate (expired, or replaced
// by a new one) must not take its devices off the network.
func shouldDeregisterOnRevocation(reason int) bool {
	return reason != ocsp.Superseded
}

// deregisterNodesOfRevokedCert takes off the network the devices that
// authenticated with a revoked certificate. Rejecting the certificate in
// EAP-TLS (OCSP) is not enough: the node stays registered, so a switch that
// falls back to MAC authentication gives it its role back.
func (c Cert) deregisterNodesOfRevokedCert(cert Cert, reason int) {
	if !shouldDeregisterOnRevocation(reason) {
		return
	}
	var rows []nodeTLS
	if err := c.DB.Table("node_tls").Select("mac, TLSClientCertSerial, TLSClientCertIssuer").Where("TLSClientCertCommonName = ?", cert.Cn).Find(&rows).Error; err != nil {
		log.LoggerWContext(c.Ctx).Error("Unable to look up the nodes of revoked certificate " + cert.Cn + ": " + err.Error())
		return
	}
	macs := macsOfCert(rows, cert)
	if len(macs) == 0 {
		return
	}
	// The API request is over by the time the nodes are deregistered.
	ctx := log.TranferLogContext(c.Ctx, context.Background())
	go deregisterNodes(ctx, macs, cert.Cn)
}
