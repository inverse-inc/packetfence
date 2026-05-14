package models

import (
	"bytes"
	"crypto"
	"crypto/dsa"
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"errors"
	"fmt"
	"math/big"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"golang.org/x/crypto/ocsp"
	pkcs12 "software.sslmate.com/src/go-pkcs12"
)

func NewCertModel(pfpki *types.Handler) *Cert {
	Cert := &Cert{}

	Cert.DB = pfpki.DB
	Cert.Ctx = *pfpki.Ctx

	return Cert
}

func (c Cert) New() (types.Info, error) {
	Information := types.Info{}
	Information.Status = http.StatusUnprocessableEntity
	// Find the profile
	var prof Profile
	if profDB := c.DB.Preload("Ca").First(&prof, c.ProfileID); profDB.Error != nil {
		Information.Error = profDB.Error.Error()
		return Information, errors.New(dbError)
	}

	// Check if the certificate is allowed to be revoked
	_, err := revokeNeeded(c.Cn, &prof, prof.DaysBeforeRenewal, c.DB)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	// Load the certificates from the database
	catls, err := tls.X509KeyPair([]byte(prof.Ca.Cert), []byte(prof.Ca.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	var SerialNumber *big.Int

	// Get serial number atomically using transaction with row-level locking
	SerialNumber, err = getNextSerialNumber(c.DB, prof.Ca.ID)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	keyOut, pub, _, err := certutils.GenerateKey(*prof.KeyType, prof.KeySize)

	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	skid, err := certutils.CalculateSKID(pub)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	Subject := c.MakeSubject()

	NotAfter := c.ValidUntil
	if c.ValidUntil.IsZero() {
		NotAfter = time.Now().AddDate(0, 0, prof.Validity)
	}

	// Prepare certificate
	cert := &x509.Certificate{
		SerialNumber:       SerialNumber,
		Subject:            Subject,
		NotBefore:          time.Now(),
		NotAfter:           NotAfter,
		SignatureAlgorithm: certutils.CompatibleSigAlgo(*prof.Ca.KeyType, prof.Digest),
		ExtKeyUsage:        certutils.Extkeyusage(strings.Split(*prof.ExtendedKeyUsage, "|")),
		KeyUsage:           x509.KeyUsage(certutils.Keyusage(strings.Split(*prof.KeyUsage, "|"))),
		SubjectKeyId:       skid,
	}

	if len(prof.OCSPUrl) > 0 {
		cert.OCSPServer = []string{prof.OCSPUrl}
	}

	Email := ""
	if len(prof.Mail) > 0 {
		Email = prof.Mail
	}
	if len(c.Mail) > 0 {
		Email = c.Mail
	}

	if len(Email) > 0 {
		for _, mail := range strings.Split(Email, ",") {
			cert.EmailAddresses = append(cert.EmailAddresses, mail)
		}
	}

	if len(c.DNSNames) > 0 {
		for _, dns := range strings.Split(c.DNSNames, ",") {
			cert.DNSNames = append(cert.DNSNames, dns)
		}
	}
	var IPAddresses []string
	if len(c.IPAddresses) > 0 {
		for _, ip := range strings.Split(c.IPAddresses, ",") {
			if net.ParseIP(ip) == nil {
				fmt.Printf("IP Address: %s - Invalid\n", ip)
			} else {
				IPAddresses = append(IPAddresses, ip)
				cert.IPAddresses = append(cert.IPAddresses, net.ParseIP(ip))
			}
		}
	}

	// Sign the certificate
	certByte, err := x509.CreateCertificate(rand.Reader, cert, cacert, pub, catls.PrivateKey)

	certBuff := new(bytes.Buffer)

	// Public key
	pem.Encode(certBuff, &pem.Block{Type: "CERTIFICATE", Bytes: certByte})

	// Start from the request body and overwrite the fields that come from
	// signing-time state (serial, CA-derived names, key/cert bytes, …).
	newCert := c
	newCert.ID = 0
	newCert.Ca = prof.Ca
	newCert.CaName = prof.Ca.Cn
	newCert.ProfileName = prof.Name
	newCert.SerialNumber = SerialNumber.String()
	newCert.IPAddresses = strings.Join(IPAddresses, ",")
	newCert.Mail = Email
	newCert.StreetAddress = strings.Join(Subject.StreetAddress, "")
	newCert.Organisation = strings.Join(Subject.Organization, "")
	newCert.OrganisationalUnit = strings.Join(Subject.OrganizationalUnit, "")
	newCert.Country = strings.Join(Subject.Country, "")
	newCert.State = strings.Join(Subject.Province, "")
	newCert.Locality = strings.Join(Subject.Locality, "")
	newCert.PostalCode = strings.Join(Subject.PostalCode, "")
	newCert.Profile = prof
	newCert.Key = keyOut.String()
	newCert.Cert = certBuff.String()
	newCert.ValidUntil = cert.NotAfter
	newCert.NotBefore = cert.NotBefore
	newCert.Subject = Subject.String()
	if err := c.DB.Create(&newCert).Error; err != nil {
		Information.Error = err.Error()
		Information.Status = http.StatusConflict
		return Information, errors.New(dbError)
	}
	log.LoggerWContext(c.Ctx).Info("Certificate " + c.Cn + " has been generated from profile " + prof.Name + " and sign by " + prof.Ca.Cn)
	Information.Entries = []Cert{newCert}
	Information.Serial = SerialNumber.String()

	return Information, nil
}

func (c Cert) GetByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var certdb []Cert
	allFields := strings.Join(sql.SqlFields(c)[:], ",")
	if val, ok := params["id"]; ok {
		c.DB.Select(allFields).Where("`id` = ?", val).First(&certdb)
	}
	if val, ok := params["cn"]; ok {
		c.DB.Select(allFields).Where("`cn` = ?", val).First(&certdb)
	}

	Information.Entries = certdb

	return Information, nil
}

func (c Cert) Paginated(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int64
	c.DB.Model(&Cert{}).Count(&count)
	counter := int(count)
	Information.TotalCount = counter
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < counter {
		sql, err := vars.Sql(c)
		if err != nil {
			Information.Error = err.Error()
			return Information, errors.New(dbError)
		}
		var certdb []Cert
		c.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&certdb)
		Information.Entries = certdb
	}

	return Information, nil
}

func (c Cert) Search(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(c)
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}
	var count int64
	c.DB.Model(&Cert{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	counter := int(count)
	Information.TotalCount = counter
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < counter {
		var certdb []Cert
		c.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&certdb)
		Information.Entries = certdb
	}

	return Information, nil
}

func (c Cert) Download(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	// Find the Cert
	var cert Cert

	if profile, ok := params["profile"]; ok {
		if val, ok := params["cn"]; ok {
			if CertDB := c.DB.Preload("Ca").Where("Cn = ? AND profile_id = ?", val, profile).Find(&cert); CertDB.Error != nil {
				Information.Error = CertDB.Error.Error()
				return Information, errors.New(dbError)
			}
		}
		if val, ok := params["id"]; ok {
			if CertDB := c.DB.Preload("Ca").Where("Id = ? AND profile_id = ?", val, profile).Find(&cert); CertDB.Error != nil {
				Information.Error = CertDB.Error.Error()
				return Information, errors.New(dbError)
			}
		}
	} else {
		if val, ok := params["id"]; ok {
			if CertDB := c.DB.Preload("Ca").First(&cert, val); CertDB.Error != nil {
				Information.Error = CertDB.Error.Error()
				return Information, errors.New(dbError)
			}
		}
	}

	// Load the certificates from the database
	certtls, err := tls.X509KeyPair([]byte(cert.Cert), []byte(cert.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	// Find the profile
	var prof Profile
	if profDB := c.DB.Where("Name = ?", cert.ProfileName).Find(&prof); profDB.Error != nil {
		Information.Error = profDB.Error.Error()
		return Information, errors.New(dbError)
	}

	certificate, err := x509.ParseCertificate(certtls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	// Load the certificates from the database
	catls, err := tls.X509KeyPair([]byte(cert.Ca.Cert), []byte(cert.Ca.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	var CaCert []*x509.Certificate

	CaCert = append(CaCert, cacert)

	// Convention on this endpoint:
	//   - params["password"] present  → "download" flow: return the binary
	//     .p12, encrypted with that exact password.
	//   - params["password"] absent   → "email" flow: encrypt with either
	//     params["mail_password"] (if the admin supplied one) or a freshly
	//     generated password, then mail the .p12 + that password.
	var password string
	if val, ok := params["password"]; ok {
		password = val
	} else if val, ok := params["mail_password"]; ok && val != "" {
		password = val
	} else {
		password = certutils.GeneratePassword()
	}
	Information.Password = password

	pkcs12, err := pkcs12.Encode(certutils.PRNG, certtls.PrivateKey, certificate, CaCert, password)

	if _, ok := params["password"]; ok {
		Information.Raw = pkcs12
		Information.ContentType = "application/x-pkcs12"
		return Information, err
	}

	mailInfo, err := emailcert(c.Ctx, cert, prof, pkcs12, password)
	// Carry the password back to the caller — the previous code did
	// `Information, err = emailcert(...)` which replaced the whole struct
	// and dropped Password. Keep our Password; merge any error/status.
	if mailInfo.Error != "" {
		Information.Error = mailInfo.Error
	}
	if mailInfo.Status != 0 {
		Information.Status = mailInfo.Status
	}
	return Information, err
}

func (c Cert) Revoke(params map[string]string) (types.Info, error) {

	Information := types.Info{}
	// Find the Cert
	var cert Cert

	reason := params["reason"]

	if profile, ok := params["profile"]; ok {
		if id, ok := params["id"]; ok {
			if CertDB := c.DB.Preload("Ca").Where("id = ? AND profile_id = ?", id, profile).Find(&cert); CertDB.Error != nil {
				Information.Error = CertDB.Error.Error()
				return Information, CertDB.Error
			}
		}
		if cn, ok := params["cn"]; ok {
			if CertDB := c.DB.Preload("Ca").Where("cn = ? AND profile_id = ?", cn, profile).Find(&cert); CertDB.Error != nil {
				Information.Error = CertDB.Error.Error()
				return Information, CertDB.Error
			}
		}
	} else {
		if id, ok := params["id"]; ok {
			if CertDB := c.DB.Preload("Ca").Where("id = ?", id).Find(&cert); CertDB.Error != nil {
				Information.Error = CertDB.Error.Error()
				return Information, CertDB.Error
			}
		}
	}

	// Find the Profile
	var profile Profile

	error := c.DB.Model(&profile).Where(&cert)
	if error.Error != nil {
		Information.Error = error.Error.Error()
		return Information, error.Error
	}

	intreason, err := strconv.Atoi(reason)
	if err != nil {
		Information.Error = "Reason unsupported"
		return Information, errors.New("Reason unsupported")
	}
	RevokeDate := time.Now().AddDate(0, 0, profile.RevokedValidUntil)
	if err := c.DB.Create(&RevokedCert{Cn: cert.Cn, Mail: cert.Mail, Ca: cert.Ca, CaID: cert.CaID, CaName: cert.CaName, StreetAddress: cert.StreetAddress, Organisation: cert.Organisation, OrganisationalUnit: cert.OrganisationalUnit, Country: cert.Country, State: cert.State, Locality: cert.Locality, PostalCode: cert.Locality, Key: cert.Key, Cert: cert.Cert, Profile: profile, ProfileID: cert.ProfileID, ProfileName: cert.ProfileName, ValidUntil: cert.ValidUntil, NotBefore: cert.NotBefore, Date: cert.Date, Revoked: RevokeDate, CRLReason: intreason, SerialNumber: cert.SerialNumber, DNSNames: cert.DNSNames, IPAddresses: cert.IPAddresses, Subject: cert.Subject}).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	if err := c.DB.Unscoped().Delete(&cert).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	return Information, nil
}

func (c Cert) CheckRenewal(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var certdb []Cert

	if CertDB := c.DB.Where("alert <> ?", 1).Find(&certdb); CertDB.Error != nil {
		Information.Error = CertDB.Error.Error()
		return Information, CertDB.Error
	}

	for _, v := range certdb {
		// Find the profile
		var prof Profile
		if profDB := c.DB.First(&prof, v.ProfileID); profDB.Error != nil {
			Information.Error = profDB.Error.Error()
			return Information, errors.New(dbError)
		}
		// Revoke due certificate
		if time.Now().Unix() > v.ValidUntil.Unix() {
			params := make(map[string]string)

			params["id"] = strconv.Itoa(int(v.ID))
			params["reason"] = strconv.Itoa(ocsp.Superseded)
			c.Revoke(params)
		}
		if prof.RenewalMail == 1 {
			if *v.Scep == false {
				if v.ValidUntil.Unix()-int64((time.Duration(prof.DaysBeforeRenewalMail)*24*time.Hour).Seconds()) < time.Now().Unix() {
					emailRenewal(c.Ctx, v, prof)
					notfalse := true
					v.Alert = &notfalse
					c.DB.Save(&v)
				}
			}
		}
	}

	return Information, nil
}

func (c Cert) Resign(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var certdb []Cert
	var err error
	//Search the existing cert in the db
	if val, ok := params["id"]; ok {
		if err = c.DB.Preload("Ca").Preload("Profile").First(&certdb, val).Error; err != nil {
			Information.Error = err.Error()
			return Information, err
		}
	}

	catls, err := tls.X509KeyPair([]byte(certdb[0].Ca.Cert), []byte(certdb[0].Ca.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	Information.Entries = certdb

	// Decode the private key
	block, _ := pem.Decode([]byte(certdb[0].Key))
	if block == nil {
		log.LoggerWContext(c.Ctx).Error("failed to decode PEM block containing public key")
	}

	var skid []byte
	var keyOut *bytes.Buffer
	keyOut = new(bytes.Buffer)
	var pub crypto.PublicKey

	keyOut, skid, pub, _, Information, err = certutils.ExtractPrivateKey(certdb[0].Profile.KeyType, block, &Information)
	if err != nil {
		return Information, err
	}

	// keyOut contain the private key
	var newcertdb []Cert

	// Get serial number atomically using transaction with row-level locking
	SerialNumber, err := getNextSerialNumber(c.DB, certdb[0].Ca.ID)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	Subject := certdb[0].MakeSubject()

	cert := &x509.Certificate{
		SerialNumber:       SerialNumber,
		Subject:            Subject,
		NotBefore:          time.Now(),
		NotAfter:           time.Now().AddDate(0, 0, certdb[0].Profile.Validity),
		SignatureAlgorithm: certutils.CompatibleSigAlgo(*certdb[0].Ca.KeyType, certdb[0].Profile.Digest),
		ExtKeyUsage:        certutils.Extkeyusage(strings.Split(*certdb[0].Profile.ExtendedKeyUsage, "|")),
		KeyUsage:           x509.KeyUsage(certutils.Keyusage(strings.Split(*certdb[0].Profile.KeyUsage, "|"))),
		SubjectKeyId:       skid,
	}
	//Overload certificate attributes
	if len(c.Profile.OCSPUrl) > 0 {
		cert.OCSPServer = []string{c.Profile.OCSPUrl}
	}

	Email := ""
	if len(certdb[0].Profile.Mail) > 0 {
		Email = certdb[0].Profile.Mail
	}
	if len(c.Mail) > 0 {
		Email = c.Mail
	}
	if len(Email) > 0 {
		for _, mail := range strings.Split(Email, ",") {
			cert.EmailAddresses = append(cert.EmailAddresses, mail)
		}
	}

	if len(c.DNSNames) > 0 {
		for _, dns := range strings.Split(c.DNSNames, ",") {
			cert.DNSNames = append(cert.DNSNames, dns)
		}
	}
	var IPAddresses []string
	if len(c.IPAddresses) > 0 {
		for _, ip := range strings.Split(c.IPAddresses, ",") {
			if net.ParseIP(ip) == nil {
				fmt.Printf("IP Address: %s - Invalid\n", ip)
			} else {
				IPAddresses = append(IPAddresses, ip)
				cert.IPAddresses = append(cert.IPAddresses, net.ParseIP(ip))
			}
		}
	}

	var certBytes []byte

	switch *certdb[0].Profile.KeyType {
	case certutils.KEY_RSA:
		certBytes, err = x509.CreateCertificate(rand.Reader, cert, cacert, pub, catls.PrivateKey.(*rsa.PrivateKey))
	case certutils.KEY_ECDSA:
		certBytes, err = x509.CreateCertificate(rand.Reader, cert, cacert, pub, catls.PrivateKey.(*ecdsa.PrivateKey))
	case certutils.KEY_DSA:
		certBytes, err = x509.CreateCertificate(rand.Reader, cert, cacert, pub, catls.PrivateKey.(*dsa.PrivateKey))
	case certutils.KEY_ED25519:
		certBytes, err = x509.CreateCertificate(rand.Reader, cert, cacert, pub, catls.PrivateKey.(ed25519.PrivateKey))
	}
	if err != nil {
		return Information, err
	}

	certBuff := new(bytes.Buffer)
	// Public key
	pem.Encode(certBuff, &pem.Block{Type: "CERTIFICATE", Bytes: certBytes})

	h := sha1.New()

	h.Write(cacert.RawIssuer)
	if err := c.DB.Model(&Cert{}).Where("cn = ?", c.Cn).Updates(map[string]interface{}{"Cn": c.Cn, "Ca": certdb[0].Ca, "CaName": certdb[0].Ca.Cn, "ProfileName": certdb[0].Profile.Name, "SerialNumber": SerialNumber.String(), "DNSNames": cert.DNSNames, "IPAddresses": strings.Join(IPAddresses, ","), "Mail": Email, "StreetAddress": cert.Subject.StreetAddress, "Organisation": cert.Subject.Organization, "OrganisationalUnit": cert.Subject.OrganizationalUnit, "Country": cert.Subject.Country, "State": cert.Subject.Province, "Locality": cert.Subject.Locality, "PostalCode": cert.Subject.PostalCode, "Profile": certdb[0].Profile, "Key": keyOut.String(), "Cert": certBuff.String(), "ValidUntil": cert.NotAfter, "NotBefore": cert.NotBefore, "Subject": cert.Subject.String()}).Error; err != nil {
		Information.Error = err.Error()
		Information.Status = http.StatusConflict
		return Information, errors.New(dbError)
	}

	c.DB.Where("cn = ? AND profile_name = ?", c.Cn, certdb[0].ProfileName).First(&newcertdb)
	Information.Entries = newcertdb
	Information.Serial = SerialNumber.String()

	return Information, nil
}

func (c Cert) MakeSubject() pkix.Name {
	var Subject pkix.Name
	Subject.CommonName = c.Cn

	//Overload certificate attributes if exist
	Organization := ""
	if len(c.Profile.Organisation) > 0 {
		Organization = c.Profile.Organisation
	}
	if len(c.Organisation) > 0 {
		Organization = c.Organisation
	}
	if len(Organization) > 0 {
		Subject.Organization = []string{Organization}
	}

	Country := ""
	if len(c.Profile.Country) > 0 {
		Country = c.Profile.Country
	}
	if len(c.Country) > 0 {
		Country = c.Country
	}
	if len(Country) > 0 {
		Subject.Country = []string{Country}
	}

	Province := ""
	if len(c.Profile.State) > 0 {
		Province = c.Profile.State
	}
	if len(c.State) > 0 {
		Province = c.State
	}
	if len(Province) > 0 {
		Subject.Province = []string{Province}
	}

	Locality := ""
	if len(c.Profile.Locality) > 0 {
		Locality = c.Profile.Locality
	}
	if len(c.Locality) > 0 {
		Locality = c.Locality
	}
	if len(Locality) > 0 {
		Subject.Locality = []string{Locality}
	}

	StreetAddress := ""
	if len(c.Profile.StreetAddress) > 0 {
		StreetAddress = c.Profile.StreetAddress
	}
	if len(c.StreetAddress) > 0 {
		StreetAddress = c.StreetAddress
	}
	if len(StreetAddress) > 0 {
		Subject.StreetAddress = []string{StreetAddress}
	}

	PostalCode := ""
	if len(c.Profile.PostalCode) > 0 {
		PostalCode = c.Profile.PostalCode
	}
	if len(c.PostalCode) > 0 {
		PostalCode = c.PostalCode
	}
	if len(PostalCode) > 0 {
		Subject.PostalCode = []string{PostalCode}
	}
	return Subject
}
