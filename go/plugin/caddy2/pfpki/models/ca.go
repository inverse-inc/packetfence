package models

import (
	"bytes"
	"context"
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
	"encoding/hex"
	"encoding/pem"
	"errors"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/cloud"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"github.com/inverse-inc/scep/scep"
	"github.com/knq/pemutil"
	"golang.org/x/crypto/ocsp"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// NewCAModel create a CAModel
func NewCAModel(pfpki *types.Handler) *CA {
	CA := &CA{}

	CA.DB = pfpki.DB
	CA.Ctx = *pfpki.Ctx

	return CA
}

// New create a new CA
func (c CA) New() (types.Info, error) {

	Information := types.Info{}

	keyOut, pub, key, err := certutils.GenerateKey(*c.KeyType, c.KeySize)

	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	skid, err := certutils.CalculateSKID(pub)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	var cadb CA

	var SerialNumber *big.Int

	if CaDB := c.DB.Last(&cadb); CaDB.Error != nil {
		SerialNumber = big.NewInt(1)
	} else {
		SerialNumber = big.NewInt(int64(cadb.ID + 1))
	}

	Subject := c.MakeSubject()

	ca := &x509.Certificate{
		SerialNumber:          SerialNumber,
		Subject:               Subject,
		NotBefore:             time.Now(),
		NotAfter:              time.Now().AddDate(0, 0, c.Days),
		IsCA:                  true,
		SignatureAlgorithm:    certutils.CompatibleSigAlgo(*c.KeyType, c.Digest),
		ExtKeyUsage:           certutils.Extkeyusage(strings.Split(*c.ExtendedKeyUsage, "|")),
		KeyUsage:              x509.KeyUsage(certutils.Keyusage(strings.Split(*c.KeyUsage, "|"))),
		BasicConstraintsValid: true,
		EmailAddresses:        []string{c.Mail},
		SubjectKeyId:          skid,
		AuthorityKeyId:        skid,
	}

	if len(c.OCSPUrl) > 0 {
		ca.OCSPServer = []string{c.OCSPUrl}
	}

	var caBytes []byte

	switch *c.KeyType {
	case certutils.KEY_RSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*rsa.PrivateKey))
	case certutils.KEY_ECDSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*ecdsa.PrivateKey))
	case certutils.KEY_DSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*dsa.PrivateKey))
	case certutils.KEY_ED25519:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(ed25519.PrivateKey))
	}
	if err != nil {
		return Information, err
	}

	cert := new(bytes.Buffer)

	// Public key
	pem.Encode(cert, &pem.Block{Type: "CERTIFICATE", Bytes: caBytes})

	// Calculate the IssuerNameHash
	catls, err := tls.X509KeyPair([]byte(cert.String()), []byte(keyOut.String()))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	h := sha1.New()

	h.Write(cacert.RawIssuer)

	newCA := CA{Cn: c.Cn, Mail: c.Mail, Organisation: c.Organisation, OrganisationalUnit: c.OrganisationalUnit, Country: c.Country, State: c.State, Locality: c.Locality, StreetAddress: c.StreetAddress, PostalCode: c.PostalCode, KeyType: c.KeyType, KeySize: c.KeySize, Digest: c.Digest, KeyUsage: c.KeyUsage, ExtendedKeyUsage: c.ExtendedKeyUsage, Days: c.Days, Key: keyOut.String(), Cert: cert.String(), IssuerKeyHash: hex.EncodeToString(skid), IssuerNameHash: hex.EncodeToString(h.Sum(nil)), OCSPUrl: c.OCSPUrl, SerialNumber: 1}
	if err := c.DB.Create(&newCA).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}

	Information.Entries = []CA{newCA}

	return Information, nil
}

func (c CA) MakeSubject() pkix.Name {
	var Subject pkix.Name
	Subject.CommonName = c.Cn

	if len(c.Organisation) > 0 {
		Subject.Organization = []string{c.Organisation}
	}

	if len(c.OrganisationalUnit) > 0 {
		Subject.OrganizationalUnit = []string{c.OrganisationalUnit}
	}

	if len(c.Country) > 0 {
		Subject.Country = []string{c.Country}
	}

	if len(c.State) > 0 {
		Subject.Province = []string{c.State}
	}

	if len(c.Locality) > 0 {
		Subject.Locality = []string{c.Locality}
	}

	if len(c.StreetAddress) > 0 {
		Subject.StreetAddress = []string{c.StreetAddress}
	}

	if len(c.PostalCode) > 0 {
		Subject.PostalCode = []string{c.PostalCode}
	}
	return Subject
}

// GetByID retreive the CA by id
func (c CA) GetByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var cadb []CA
	if val, ok := params["id"]; ok {
		allFields := strings.Join(sql.SqlFields(c)[:], ",")
		c.DB.Select(allFields).Where("`id` = ?", val).First(&cadb)
	}
	Information.Entries = cadb

	return Information, nil
}

// Fix calculate the IssuerKeyHash and IssuerNameHash
func (c CA) Fix() (types.Info, error) {
	Information := types.Info{}
	var cadb []CA

	c.DB.Find(&cadb)
	for _, v := range cadb {
		if v.IssuerNameHash == "" {

			// Calculate the IssuerNameHash
			catls, err := tls.X509KeyPair([]byte(v.Cert), []byte(v.Key))
			if err != nil {
				Information.Error = err.Error()
				return Information, err
			}
			cacert, err := x509.ParseCertificate(catls.Certificate[0])
			if err != nil {
				Information.Error = err.Error()
				return Information, err
			}
			h := sha1.New()

			h.Write(cacert.RawIssuer)
			// var store pemutil.Store
			store := make(map[pemutil.BlockType]interface{})

			pemutil.Decode(store, []byte(v.Cert))
			var skid []byte
			for _, pemUtil := range store {
				cert := pemUtil.(*x509.Certificate)
				skid, _ = certutils.CalculateSKID(cert.PublicKey)
			}

			v.IssuerKeyHash = hex.EncodeToString(skid)
			v.IssuerNameHash = hex.EncodeToString(h.Sum(nil))
			c.DB.Save(&v)
		}
	}

	return Information, nil
}

// Paginated return the CA list paginated
func (c CA) Paginated(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int64
	c.DB.Model(&CA{}).Count(&count)
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
		var cadb []CA
		c.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&cadb)
		Information.Entries = cadb
	}

	return Information, nil
}

// Search for the CA
func (c CA) Search(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(c)
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}
	var count int64
	c.DB.Model(&CA{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	counter := int(count)

	Information.TotalCount = counter
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < counter {
		var cadb []CA
		c.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&cadb)
		Information.Entries = cadb
	}

	return Information, nil
}

// FindSCEPProfile search the SCEP Profile by the profile name
func (c *CA) FindSCEPProfile(options []string) ([]Profile, error) {
	var profiledb []Profile
	profile := &Profile{}
	if len(options) >= 1 {
		if err := c.DB.Preload("ScepServer").Where("name = ? and `scep_enabled` = ?", options[0], "1").First(profile).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return profiledb, errors.New("Unknow profile.")
			}
			return profiledb, errors.New(dbError)
		}
		profiledb = append(profiledb, *profile)
	} else {
		c.DB.Preload("ScepServer").Where("`scep_enabled` = ?", "1").First(&profiledb)
	}
	c.SCEPAssociateProfile = profiledb[0].Name

	return profiledb, nil

}

// CA return the CA public key based on the profile name (SCEP)
func (c CA) CA(pass []byte, options ...string) ([]*x509.Certificate, *rsa.PrivateKey, error) {

	var profiledb []Profile

	profiledb, err := c.FindSCEPProfile(options)

	if err != nil {
		return nil, nil, err
	}

	// Proxy the request if a SCEPServer is defined in the profil

	var ca CA

	if err := c.DB.First(&ca, profiledb[0].CaID).Error; err != nil {
		c.DB.First(&ca)
	}

	catls, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	key, err := certutils.LoadKey([]byte(ca.Key), pass)
	return []*x509.Certificate{cacert}, key, err
}

// CA return the CA public key based on the profile name (SCEP)
func (c CA) CAbyProfile(pass []byte, profilename string) ([]*x509.Certificate, *rsa.PrivateKey, error) {
	profile := &Profile{}
	if err := c.DB.Where("name = ?", profilename).First(profile).Error; err != nil {
		return nil, nil, err
	}

	var ca CA

	if err := c.DB.First(&ca, profile.CaID).Error; err != nil {
		c.DB.First(&ca)
	}

	catls, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	key, err := certutils.LoadKey([]byte(ca.Key), pass)
	return []*x509.Certificate{cacert}, key, err
}

// Put create the public key in the DB (SCEP)
func (c CA) Put(cn string, crt *x509.Certificate, options ...string) error {

	attributeMap := certutils.GetDNFromCert(crt.Subject)

	publicKey := new(bytes.Buffer)

	pem.Encode(publicKey, &pem.Block{Type: "CERTIFICATE", Bytes: crt.Raw})

	profiledb, err := c.FindSCEPProfile(options)

	if err != nil {
		return err
	}

	var ca CA

	if err := c.DB.First(&ca, profiledb[0].CaID).Error; err != nil {
		c.DB.First(&ca)
	}
	notFalse := true
	var IPAddresses []string
	for _, IP := range crt.IPAddresses {
		IPAddresses = append(IPAddresses, IP.String())
	}

	if err := c.DB.Create(&Cert{Cn: cn, Ca: ca, CaName: ca.Cn, ProfileName: profiledb[0].Name, SerialNumber: crt.SerialNumber.String(), Mail: strings.Join(crt.EmailAddresses, ","), StreetAddress: attributeMap["streetAddress"], Organisation: attributeMap["O"], OrganisationalUnit: attributeMap["OU"], Country: attributeMap["C"], State: attributeMap["ST"], Locality: attributeMap["L"], PostalCode: attributeMap["postalCode"], DNSNames: strings.Join(crt.DNSNames, ","), IPAddresses: strings.Join(IPAddresses, ","), Profile: profiledb[0], Key: "", Cert: publicKey.String(), ValidUntil: crt.NotAfter, NotBefore: crt.NotBefore, Scep: &notFalse, Subject: crt.Subject.String()}).Error; err != nil {
		return errors.New(dbError)
	}

	return nil
}

// Serial return the serial number
func (c CA) Serial(options ...string) (*big.Int, error) {

	profiledb, err := c.FindSCEPProfile(options)

	if err != nil {
		return nil, err
	}

	return c.FindSerial(profiledb[0])
}

// FindSerial atomically allocates the next serial number for a Profile's CA.
// If the profile's CA id can't be found, falls back to the first CA row.
func (c CA) FindSerial(p Profile) (*big.Int, error) {
	return nextSerialNumber(c.DB, p.CaID, true)
}

// getNextSerialNumber atomically increments and returns the next serial
// number for the given CA. Uses a row-locked transaction to prevent race
// conditions.
func getNextSerialNumber(db *gorm.DB, caID uint) (*big.Int, error) {
	return nextSerialNumber(db, caID, false)
}

// nextSerialNumber holds the shared row-locked increment used by both
// FindSerial (with a fallback to the first CA) and getNextSerialNumber.
func nextSerialNumber(db *gorm.DB, caID uint, fallbackToFirst bool) (*big.Int, error) {
	var serialNumber int

	err := db.Transaction(func(tx *gorm.DB) error {
		ca := &CA{}
		locked := tx.Clauses(clause.Locking{Strength: "UPDATE"})
		if err := locked.First(ca, caID).Error; err != nil {
			if !fallbackToFirst {
				return err
			}
			if err := locked.First(ca).Error; err != nil {
				return err
			}
		}

		serialNumber = ca.SerialNumber
		ca.SerialNumber = ca.SerialNumber + 1
		return tx.Save(ca).Error
	})

	if err != nil {
		return nil, err
	}

	return big.NewInt(int64(serialNumber)), nil
}

func (c CA) HasCN(cn string, allowTime int, cert *x509.Certificate, revokeOldCertificate bool, options ...string) (bool, error) {
	var prof Profile
	if err := c.DB.Where("name = ?", options[0]).First(&prof).Error; err != nil {
		return false, err
	}
	return revokeNeeded(cn, &prof, allowTime, c.DB)
}

// revokeNeeded decides whether a fresh leaf with the given CN can be issued
// under prof. Callers must pass an already-loaded Profile; previously this
// function ran its own SELECT * FROM pki_profiles even though Cert.New
// (its main caller) already had it.
func revokeNeeded(cn string, prof *Profile, allowTime int, c *gorm.DB) (bool, error) {
	if prof.AllowDuplicatedCN == 1 {
		// Allow duplicated CN in the DB for this profile
		if prof.MaximumDuplicatedCN == 0 {
			return true, nil
		}
		var certifs []Cert
		certDB := c.Where("cn = ? AND profile_name = ?", cn, prof.Name).Find(&certifs)
		if certDB.Error == nil {
			// Do we have to revoke some of them ?
			revoked := 0
			for _, certificat := range certifs {
				certificat.DB = c
				if maybeRevokeExpiring(&certificat, allowTime) {
					revoked++
				}
			}
			if int(certDB.RowsAffected)-revoked >= prof.MaximumDuplicatedCN {
				return false, errors.New("Certificate with this Subject already exist: " + cn)
			}
			return true, nil
		}
	}

	var certif Cert
	certDB := c.Where("Cn = ? AND profile_name = ?", cn, prof.Name).Find(&certif)
	if certDB.Error != nil || certDB.RowsAffected == 0 {
		// No matching cert in the DB
		return true, nil
	}
	certif.DB = c
	if maybeRevokeExpiring(&certif, allowTime) {
		return true, nil
	}
	return false, errors.New("Certificate with this Subject already exist: " + cn)
}

// maybeRevokeExpiring revokes the cert if it's close enough to its NotAfter
// (allowTime days, or 0 meaning "revoke unconditionally") and returns true
// when a revocation happened.
func maybeRevokeExpiring(c *Cert, allowTime int) bool {
	store := make(map[pemutil.BlockType]interface{})
	if err := pemutil.Decode(store, []byte(c.Cert)); err != nil {
		return false
	}
	threshold := time.Now().Add(time.Duration(allowTime) * 24 * time.Hour)
	for _, pemUtil := range store {
		cert, ok := pemUtil.(*x509.Certificate)
		if !ok {
			continue
		}
		if allowTime == 0 || cert.NotAfter.Before(threshold) {
			c.Revoke(map[string]string{
				"id":     strconv.Itoa(int(c.ID)),
				"reason": strconv.Itoa(ocsp.Superseded),
			})
			return true
		}
	}
	return false
}

// SCEP Verify
func (c CA) Verify(m *scep.CSRReqMessage) (bool, error) {
	prof, _ := c.GetProfileByName(c.SCEPAssociateProfile)

	if prof.CloudEnabled == 1 {
		vcloud, err := cloud.Create(c.Ctx, "intune", prof.CloudService)
		if err != nil {
			return false, err
		}
		err = vcloud.ValidateRequest(c.Ctx, m.CSR.Raw)

		if err != nil {
			return false, err
		}
		c.Cloud = vcloud
		return true, nil
	}
	return true, nil
}

func (c CA) FailureNotify(cert *x509.Certificate, m *scep.CSRReqMessage, message string) {
	if c.Cloud != nil {
		c.Cloud.FailureReply(c.Ctx, cert, m.CSR.Raw, message)
	}
}

func (c CA) SuccessNotify(cert *x509.Certificate, m *scep.CSRReqMessage, message string) {
	if c.Cloud != nil {
		c.Cloud.SuccessReply(c.Ctx, cert, m.CSR.Raw, message)
	}
}

func (c CA) GetProfileByName(name string) (*Profile, error) {
	var profiledb []Profile
	c.DB.Where("name = ?", name).First(&profiledb)

	return &profiledb[0], nil
}

func (c CA) Resign(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var cadb []CA
	var err error
	if val, ok := params["id"]; ok {
		if err = c.DB.First(&cadb, val).Error; err != nil {
			Information.Error = err.Error()
			return Information, err
		}

	}

	Information.Entries = cadb

	block, _ := pem.Decode([]byte(cadb[0].Key))
	if block == nil {
		log.LoggerWContext(c.Ctx).Error("failed to decode PEM block containing public key")
	}

	var skid []byte
	var keyOut *bytes.Buffer
	keyOut = new(bytes.Buffer)
	var key crypto.PrivateKey
	var pub crypto.PublicKey
	keyOut, skid, pub, key, Information, err = certutils.ExtractPrivateKey(c.KeyType, block, &Information)
	if err != nil {
		return Information, err
	}

	var cadbprevious CA
	var newcadb []CA

	var SerialNumber *big.Int

	if CaDB := c.DB.Last(&cadbprevious); CaDB.Error != nil {
		SerialNumber = big.NewInt(1)
	} else {
		SerialNumber = big.NewInt(int64(cadbprevious.ID + 1))
	}

	Subject := c.MakeSubject()

	ca := &x509.Certificate{
		SerialNumber:          SerialNumber,
		Subject:               Subject,
		NotBefore:             time.Now(),
		NotAfter:              time.Now().AddDate(0, 0, c.Days),
		IsCA:                  true,
		SignatureAlgorithm:    certutils.CompatibleSigAlgo(*c.KeyType, c.Digest),
		ExtKeyUsage:           certutils.Extkeyusage(strings.Split(*c.ExtendedKeyUsage, "|")),
		KeyUsage:              x509.KeyUsage(certutils.Keyusage(strings.Split(*c.KeyUsage, "|"))),
		BasicConstraintsValid: true,
		EmailAddresses:        []string{c.Mail},
		SubjectKeyId:          skid,
		AuthorityKeyId:        skid,
	}

	if len(c.OCSPUrl) > 0 {
		ca.OCSPServer = []string{c.OCSPUrl}
	}

	var caBytes []byte

	switch *c.KeyType {
	case certutils.KEY_RSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*rsa.PrivateKey))
	case certutils.KEY_ECDSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*ecdsa.PrivateKey))
	case certutils.KEY_DSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*dsa.PrivateKey))
	case certutils.KEY_ED25519:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(ed25519.PrivateKey))
	}
	if err != nil {
		return Information, err
	}

	cert := new(bytes.Buffer)
	// Public key
	pem.Encode(cert, &pem.Block{Type: "CERTIFICATE", Bytes: caBytes})

	// Calculate the IssuerNameHash
	catls, err := tls.X509KeyPair([]byte(cert.String()), []byte(keyOut.String()))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	h := sha1.New()

	h.Write(cacert.RawIssuer)

	if err := c.DB.Model(&CA{}).Where("cn = ?", c.Cn).Updates(map[string]interface{}{"Cn": c.Cn, "Mail": c.Mail, "Organisation": c.Organisation, "OrganisationalUnit": c.OrganisationalUnit, "Country": c.Country, "State": c.State, "Locality": c.Locality, "StreetAddress": c.StreetAddress, "PostalCode": c.PostalCode, "KeyType": c.KeyType, "KeySize": c.KeySize, "Digest": c.Digest, "KeyUsage": c.KeyUsage, "ExtendedKeyUsage": c.ExtendedKeyUsage, "Days": c.Days, "Key": keyOut.String(), "Cert": cert.String(), "IssuerKeyHash": hex.EncodeToString(skid), "IssuerNameHash": hex.EncodeToString(h.Sum(nil)), "OCSPUrl": c.OCSPUrl}).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}

	c.DB.Where("cn = ?", c.Cn).First(&newcadb)
	Information.Entries = newcadb

	return Information, nil
}

func (c CA) GenerateCSR(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var cadb []CA
	var err error
	if val, ok := params["id"]; ok {
		if err = c.DB.First(&cadb, val).Error; err != nil {
			Information.Status = http.StatusNotFound
			Information.Error = err.Error()
			return Information, err
		}

	}
	catls, err := tls.X509KeyPair([]byte(cadb[0].Cert), []byte(cadb[0].Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	Information.Entries = cadb

	// Use the stored CA's KeyType/Digest, not the request body's — the
	// receiver may only carry the subject fields the caller wants to change,
	// and the signing algorithm is bound to the existing private key anyway.
	template := x509.CertificateRequest{
		Subject:            c.MakeSubject(),
		SignatureAlgorithm: certutils.CompatibleSigAlgo(*cadb[0].KeyType, cadb[0].Digest),
	}
	csrBuff := new(bytes.Buffer)
	csrBytes, err := x509.CreateCertificateRequest(rand.Reader, &template, catls.PrivateKey)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	pem.Encode(csrBuff, &pem.Block{Type: "CERTIFICATE REQUEST", Bytes: csrBytes})
	Information.Entries = csrBuff.String()

	if err := c.DB.Model(&CA{}).Where("cn = ?", c.Cn).Updates(map[string]interface{}{"Cn": c.Cn, "Mail": c.Mail, "Organisation": c.Organisation, "OrganisationalUnit": c.OrganisationalUnit, "Country": c.Country, "State": c.State, "Locality": c.Locality, "StreetAddress": c.StreetAddress, "PostalCode": c.PostalCode, "KeyType": c.KeyType, "KeySize": c.KeySize, "Digest": c.Digest, "KeyUsage": c.KeyUsage, "ExtendedKeyUsage": c.ExtendedKeyUsage, "Days": c.Days, "OCSPUrl": c.OCSPUrl}).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}

	return Information, err

}

func (c CA) Update(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var cadb []CA
	var err error
	if val, ok := params["id"]; ok {
		if err = c.DB.First(&cadb, val).Error; err != nil {
			Information.Status = http.StatusNotFound
			Information.Error = err.Error()
			return Information, err
		}
	}
	_, err = tls.X509KeyPair([]byte(c.Cert), []byte(cadb[0].Key))

	if err != nil {
		Information.Error = err.Error()
		Information.Status = http.StatusUnprocessableEntity
		return Information, nil
	}
	cadb[0].Cert = c.Cert
	c.DB.Save(&cadb[0])
	Information.Entries = cadb[0]
	return Information, err
}

// EST
func (c CA) CACerts(ctx context.Context, aps string, r *http.Request) ([]*x509.Certificate, error) {
	var certs []*x509.Certificate
	catls, err := tls.X509KeyPair([]byte(c.Cert), []byte(c.Key))
	if err != nil {
		log.LoggerWContext(c.Ctx).Error(err.Error())
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		log.LoggerWContext(c.Ctx).Error(err.Error())
	}
	certs = append(certs, cacert)
	return certs, nil
}
