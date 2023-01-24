package certstore

import (
	"context"
	"crypto/x509"
	"encoding/pem"
	"os"
	"strings"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type CertStore struct {
	eap          pfconfigdriver.EAPConfiguration
	certificates map[string]map[string][]byte
}

func ExtractAllFromPacketFence() []*x509.Certificate {
	var ctx = context.Background()
	ctx = log.LoggerNewContext(ctx)

	var keyEAPConfiguration pfconfigdriver.EAPConfiguration

	pfconfigdriver.FetchDecodeSocket(ctx, &keyEAPConfiguration)

	var certStore = &CertStore{}

	certStore.eap = keyEAPConfiguration

	certStore.Init(ctx)
	var err error
	var rest []byte
	var CaCert []*x509.Certificate
	for tls := range certStore.certificates {
		for key := range certStore.certificates[tls] {
			if strings.HasPrefix(string(certStore.certificates[tls][key]), "-----") {
				rest = certStore.certificates[tls][key]
			} else {
				rest, err = os.ReadFile(string(certStore.certificates[tls][key]))
				if err != nil {
					continue
				}
			}
			var block *pem.Block
			for len(rest) > 0 {
				block, rest = pem.Decode(rest)
				pub, err := x509.ParseCertificate(block.Bytes)
				if err != nil {
					panic(err)
				}
				CaCert = append(CaCert, pub)
			}
		}
	}
	return CaCert
}

// Init initialze the certificates map
func (r *CertStore) Init(ctx context.Context) {
	certificate := make(map[string]map[string][]byte)
	// Read Fresh configuration
	pfconfigdriver.FetchDecodeSocketCache(ctx, &pfconfigdriver.Config.EAPConfiguration)
	r.eap = pfconfigdriver.Config.EAPConfiguration

	for eapkey := range r.eap.Element {
		for tlskey := range r.eap.Element[eapkey].TLS {
			certificate[tlskey] = make(map[string][]byte)
			if r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Default == "yes" {
				certificate[tlskey]["cert"] = []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Cert)
				certificate[tlskey]["ca"] = []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Ca)
			} else {
				certificate[tlskey]["cert"] = concatAppend([][]byte{[]byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Cert), []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Intermediate)})
				certificate[tlskey]["ca"] = []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Ca)
			}
		}
	}
	r.certificates = certificate
}

func concatAppend(slices [][]byte) []byte {
	var tmp []byte
	for _, s := range slices {
		tmp = append(tmp, s...)
		tmp = append(tmp, byte('\r'))
		tmp = append(tmp, byte('\n'))
	}
	return tmp
}
