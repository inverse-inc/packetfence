package models

import (
	"bytes"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"github.com/inverse-inc/scep/cryptoutil"
)

func NewCsrModel(pfpki *types.Handler) *CSR {
	Csr := &CSR{}

	Csr.DB = pfpki.DB
	Csr.Ctx = *pfpki.Ctx

	return Csr
}

func (csr CSR) New(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	Information.Status = http.StatusUnprocessableEntity
	// Find the profile
	var prof Profile
	if val, ok := params["id"]; ok {

		if profDB := csr.DB.First(&prof, val); profDB.Error != nil {
			Information.Error = profDB.Error.Error()
			return Information, errors.New(dbError)
		}
	} else {
		return Information, errors.New("Missing the profile id in the url")

	}
	attributes := ProfileAttributes(prof)
	// Find the CA
	var ca CA
	if err := csr.DB.First(&ca, prof.CaID).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}

	// Decode the CSR. Accept PEM (with BEGIN/END markers) or raw DER.
	var (
		err error
		der []byte
	)
	if block, _ := pem.Decode([]byte(csr.Csr)); block != nil {
		der = block.Bytes
	} else {
		der = []byte(csr.Csr)
	}

	certRequest, err := x509.ParseCertificateRequest(der)
	if err != nil {
		Information.Error = err.Error()
		Information.Status = http.StatusUnprocessableEntity
		return Information, err
	}

	id, err := cryptoutil.GenerateSubjectKeyID(certRequest.PublicKey)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	ca.DB = csr.DB

	serial, err := ca.FindSerial(prof)

	if err != nil {
		return Information, err
	}

	Subject := certutils.MakeSubject(certRequest.Subject, attributes)
	Subject.CommonName = certRequest.Subject.CommonName

	ExtKeyUsage := certutils.Extkeyusage(strings.Split(attributes["ExtendedKeyUsage"], "|"))
	KeyUsage := x509.KeyUsage(certutils.Keyusage(strings.Split(attributes["KeyUsage"], "|")))

	// create cert template
	v, _ := strconv.Atoi(attributes["Digest"])
	SignatureAlgorithm := certutils.CompatibleSigAlgo(*ca.KeyType, x509.SignatureAlgorithm(v))

	var ExtraExtensions []pkix.Extension

	for _, v := range certRequest.Extensions {
		if v.Id.String() != "2.5.29.37" {
			if v.Id.String() == "2.5.29.17" {
				ext, err := certutils.ForEachSAN(v.Value, attributes)
				if err == nil {
					ExtraExtensions = append(ExtraExtensions, ext)
				}
			} else {
				ExtraExtensions = append(ExtraExtensions, v)
			}
		}

	}

	tmpl := &x509.Certificate{
		SerialNumber:       serial,
		Subject:            Subject,
		NotBefore:          time.Now().Add(-600).UTC(),
		NotAfter:           time.Now().AddDate(0, 0, prof.Validity).UTC(),
		SubjectKeyId:       id,
		KeyUsage:           KeyUsage,
		ExtKeyUsage:        ExtKeyUsage,
		SignatureAlgorithm: SignatureAlgorithm,
		DNSNames:           certRequest.DNSNames,
		EmailAddresses:     certRequest.EmailAddresses,
		IPAddresses:        certRequest.IPAddresses,
		URIs:               certRequest.URIs,
		ExtraExtensions:    ExtraExtensions,
	}

	if len(attributes["OCSPUrl"]) > 0 {
		tmpl.OCSPServer = []string{attributes["OCSPUrl"]}
	}

	if len(attributes["Mail"]) > 0 {
		tmpl.EmailAddresses = []string{attributes["Mail"]}
	}

	// Load the certificates from the database
	catls, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	// Sign the certificate
	certByte, err := x509.CreateCertificate(rand.Reader, tmpl, cacert, certRequest.PublicKey, catls.PrivateKey)

	certBuff := new(bytes.Buffer)

	// Public key
	pem.Encode(certBuff, &pem.Block{Type: "CERTIFICATE", Bytes: certByte})

	c := &Cert{}

	c.DB = csr.DB
	c.Ctx = csr.Ctx

	var IPAddresses []string
	for _, IP := range certRequest.IPAddresses {
		IPAddresses = append(IPAddresses, IP.String())
	}

	attributeMap := certutils.GetDNFromCert(Subject)

	certif, err := x509.ParseCertificate(certByte)
	name := certutils.CertName(certif)
	notfalse := true

	newCert := Cert{Cn: name, Ca: ca, CaName: ca.Cn, ProfileName: prof.Name, SerialNumber: serial.String(), DNSNames: c.DNSNames, IPAddresses: strings.Join(IPAddresses, ","), Mail: strings.Join(certRequest.EmailAddresses, ","), StreetAddress: attributeMap["streetAddress"], Organisation: attributeMap["O"], OrganisationalUnit: attributeMap["OU"], Country: attributeMap["C"], State: attributeMap["ST"], Locality: attributeMap["L"], PostalCode: attributeMap["postalCode"], Profile: prof, Cert: certBuff.String(), ValidUntil: tmpl.NotAfter, Subject: Subject.String(), Csr: &notfalse}
	if err := c.DB.Create(&newCert).Error; err != nil {
		Information.Error = err.Error()
		Information.Status = http.StatusConflict
		return Information, errors.New(dbError)
	}
	Information.Entries = []Cert{newCert}
	Information.Serial = serial.String()

	return Information, nil

}
