package models

import (
	"bytes"
	"crypto/dsa"
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/rsa"
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

	// We can't filter `alert <> 1` here anymore: under the multi-threshold
	// schedule a cert may have been notified at the 14d threshold but
	// still need 7d/1d notifications. Iterate every row and let the
	// threshold logic gate the per-cert decision.
	if CertDB := c.DB.Find(&certdb); CertDB.Error != nil {
		Information.Error = CertDB.Error.Error()
		return Information, CertDB.Error
	}

	now := time.Now()
	for _, v := range certdb {
		var prof Profile
		if profDB := c.DB.First(&prof, v.ProfileID); profDB.Error != nil {
			Information.Error = profDB.Error.Error()
			return Information, errors.New(dbError)
		}

		// Revoke due certificate
		if now.Unix() > v.ValidUntil.Unix() {
			c.Revoke(map[string]string{
				"id":     strconv.Itoa(int(v.ID)),
				"reason": strconv.Itoa(ocsp.Superseded),
			})
			continue
		}

		if prof.RenewalMail != 1 {
			continue
		}
		if v.Scep != nil && *v.Scep {
			// SCEP-issued certs renew via the device, not by email.
			continue
		}

		due, fallbackOneShot := nextDueRenewalThreshold(now, v, prof)
		if due < 0 {
			continue
		}

		if _, err := emailRenewal(c.Ctx, v, prof); err != nil {
			log.LoggerWContext(c.Ctx).Error(fmt.Sprintf("renewal mail for cert %d failed: %v", v.ID, err))
			continue
		}

		if fallbackOneShot {
			notfalse := true
			v.Alert = &notfalse
		} else {
			v.AlertedDays = appendAlertedDay(v.AlertedDays, due)
		}
		if err := c.DB.Save(&v).Error; err != nil {
			log.LoggerWContext(c.Ctx).Error(fmt.Sprintf("persist alert state for cert %d failed: %v", v.ID, err))
		}
	}

	return Information, nil
}

// nextDueRenewalThreshold returns the smallest (most-imminent) threshold
// in days for which a renewal email should be sent now and hasn't been
// sent yet. -1 means nothing is due.
//
// fallbackOneShot tells the caller to record the decision on the legacy
// Cert.Alert boolean rather than appending to AlertedDays — used when the
// profile is configured with the old single-threshold field and no list.
func nextDueRenewalThreshold(now time.Time, cert Cert, prof Profile) (threshold int, fallbackOneShot bool) {
	thresholds, multi := parseRenewalThresholds(prof)
	if len(thresholds) == 0 {
		return -1, false
	}

	if !multi {
		// Legacy: one threshold, gated by the boolean Alert flag.
		if cert.Alert != nil && *cert.Alert {
			return -1, true
		}
		T := thresholds[0]
		if !thresholdCrossed(now, cert.ValidUntil, T) {
			return -1, true
		}
		return T, true
	}

	already := parseAlertedDays(cert.AlertedDays)
	// Send for the smallest (closest-to-expiry) unsent crossed threshold,
	// so the operator gets one mail per cron tick — not a backlog.
	for _, T := range thresholds {
		if already[T] {
			continue
		}
		if !thresholdCrossed(now, cert.ValidUntil, T) {
			continue
		}
		return T, false
	}
	return -1, false
}

// thresholdCrossed reports whether `now` is within `T` days of NotAfter.
func thresholdCrossed(now, notAfter time.Time, T int) bool {
	return now.Add(time.Duration(T) * 24 * time.Hour).After(notAfter) ||
		now.Add(time.Duration(T) * 24 * time.Hour).Equal(notAfter)
}

// parseRenewalThresholds returns the configured thresholds sorted in
// ascending order (most-imminent first when iterated). multi=true means
// the profile uses the new RenewalMailDays list; multi=false is the
// legacy single-value path and the slice has at most one element.
func parseRenewalThresholds(prof Profile) (thresholds []int, multi bool) {
	if strings.TrimSpace(prof.RenewalMailDays) != "" {
		for _, part := range strings.Split(prof.RenewalMailDays, ",") {
			n, err := strconv.Atoi(strings.TrimSpace(part))
			if err != nil || n < 0 {
				continue
			}
			thresholds = append(thresholds, n)
		}
		sortAscending(thresholds)
		return thresholds, true
	}
	if prof.DaysBeforeRenewalMail > 0 {
		return []int{prof.DaysBeforeRenewalMail}, false
	}
	return nil, false
}

func parseAlertedDays(s string) map[int]bool {
	out := make(map[int]bool)
	if s == "" {
		return out
	}
	for _, part := range strings.Split(s, ",") {
		if n, err := strconv.Atoi(strings.TrimSpace(part)); err == nil {
			out[n] = true
		}
	}
	return out
}

func appendAlertedDay(s string, day int) string {
	set := parseAlertedDays(s)
	set[day] = true
	days := make([]int, 0, len(set))
	for d := range set {
		days = append(days, d)
	}
	sortAscending(days)
	parts := make([]string, len(days))
	for i, d := range days {
		parts[i] = strconv.Itoa(d)
	}
	return strings.Join(parts, ",")
}

func sortAscending(xs []int) {
	for i := 1; i < len(xs); i++ {
		for j := i; j > 0 && xs[j-1] > xs[j]; j-- {
			xs[j-1], xs[j] = xs[j], xs[j-1]
		}
	}
}

// Resign re-issues a leaf using the same private key and Subject/SAN as
// the existing row, updating only the serial number and validity window.
// The intent is "the deployed cert keeps working without touching its
// private key, but the device sees a freshly-dated certificate".
//
// Identity fields (Subject, DNSNames, IPAddresses, EmailAddresses,
// OCSPServer, KeyUsage, ExtKeyUsage) are read from the original cert's
// parsed PEM, so they survive even an empty request body. Non-empty
// fields on the receiver (Mail, DNSNames, IPAddresses, Profile.OCSPUrl)
// still override, preserving the existing "edit during resign" UX.
func (c Cert) Resign(params map[string]string) (types.Info, error) {
	Information := types.Info{}

	id, ok := params["id"]
	if !ok {
		return Information, errors.New("missing cert id")
	}

	var existing Cert
	if err := c.DB.Preload("Ca").Preload("Profile").First(&existing, id).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	catls, err := tls.X509KeyPair([]byte(existing.Ca.Cert), []byte(existing.Ca.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	// Parse the existing leaf so we can copy its Subject + SANs verbatim.
	// This is the anchor that makes "identical except dates" possible.
	leafBlock, _ := pem.Decode([]byte(existing.Cert))
	if leafBlock == nil {
		return Information, errors.New("existing cert PEM did not decode")
	}
	oldLeaf, err := x509.ParseCertificate(leafBlock.Bytes)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	// Re-encode the existing private key so the row's Key column stays
	// in a known PEM shape; the key material is unchanged.
	keyBlock, _ := pem.Decode([]byte(existing.Key))
	if keyBlock == nil {
		log.LoggerWContext(c.Ctx).Error("failed to decode PEM block containing private key")
		return Information, errors.New("existing key PEM did not decode")
	}
	keyOut, _, pub, _, Information, err := certutils.ExtractPrivateKey(existing.Profile.KeyType, keyBlock, &Information)
	if err != nil {
		return Information, err
	}

	SerialNumber, err := getNextSerialNumber(c.DB, existing.Ca.ID)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	// Build the template from the parsed old cert, then apply any
	// caller-supplied overrides on top.
	tmpl := &x509.Certificate{
		SerialNumber:       SerialNumber,
		Subject:            oldLeaf.Subject,
		NotBefore:          time.Now(),
		NotAfter:           time.Now().AddDate(0, 0, existing.Profile.Validity),
		SignatureAlgorithm: certutils.CompatibleSigAlgo(*existing.Ca.KeyType, existing.Profile.Digest),
		KeyUsage:           oldLeaf.KeyUsage,
		ExtKeyUsage:        oldLeaf.ExtKeyUsage,
		SubjectKeyId:       oldLeaf.SubjectKeyId,
		DNSNames:           oldLeaf.DNSNames,
		IPAddresses:        oldLeaf.IPAddresses,
		EmailAddresses:     oldLeaf.EmailAddresses,
		URIs:               oldLeaf.URIs,
		OCSPServer:         oldLeaf.OCSPServer,
	}

	// Optional overrides from the request body. Non-empty values replace
	// the parsed-cert defaults; empty leaves the original behavior.
	if len(c.Profile.OCSPUrl) > 0 {
		tmpl.OCSPServer = []string{c.Profile.OCSPUrl}
	}
	if len(c.Mail) > 0 {
		tmpl.EmailAddresses = strings.Split(c.Mail, ",")
	}
	if len(c.DNSNames) > 0 {
		tmpl.DNSNames = strings.Split(c.DNSNames, ",")
	}
	var ipStrings []string
	if len(c.IPAddresses) > 0 {
		tmpl.IPAddresses = tmpl.IPAddresses[:0]
		for _, ip := range strings.Split(c.IPAddresses, ",") {
			parsed := net.ParseIP(ip)
			if parsed == nil {
				log.LoggerWContext(c.Ctx).Warn(fmt.Sprintf("Resign: ignoring invalid IP %q", ip))
				continue
			}
			ipStrings = append(ipStrings, ip)
			tmpl.IPAddresses = append(tmpl.IPAddresses, parsed)
		}
	} else {
		for _, ip := range oldLeaf.IPAddresses {
			ipStrings = append(ipStrings, ip.String())
		}
	}

	var certBytes []byte
	switch *existing.Profile.KeyType {
	case certutils.KEY_RSA:
		certBytes, err = x509.CreateCertificate(rand.Reader, tmpl, cacert, pub, catls.PrivateKey.(*rsa.PrivateKey))
	case certutils.KEY_ECDSA:
		certBytes, err = x509.CreateCertificate(rand.Reader, tmpl, cacert, pub, catls.PrivateKey.(*ecdsa.PrivateKey))
	case certutils.KEY_DSA:
		certBytes, err = x509.CreateCertificate(rand.Reader, tmpl, cacert, pub, catls.PrivateKey.(*dsa.PrivateKey))
	case certutils.KEY_ED25519:
		certBytes, err = x509.CreateCertificate(rand.Reader, tmpl, cacert, pub, catls.PrivateKey.(ed25519.PrivateKey))
	}
	if err != nil {
		return Information, err
	}

	certBuff := new(bytes.Buffer)
	pem.Encode(certBuff, &pem.Block{Type: "CERTIFICATE", Bytes: certBytes})

	// Update the existing row by primary key — the previous WHERE cn = ?
	// match was fragile when the request body omitted Cn (a "click and
	// renew" with no edits) and could silently update nothing.
	existing.SerialNumber = SerialNumber.String()
	existing.NotBefore = tmpl.NotBefore
	existing.ValidUntil = tmpl.NotAfter
	existing.Cert = certBuff.String()
	existing.Key = keyOut.String()
	existing.DNSNames = strings.Join(tmpl.DNSNames, ",")
	existing.IPAddresses = strings.Join(ipStrings, ",")
	if len(c.Mail) > 0 {
		existing.Mail = c.Mail
	}
	if err := c.DB.Save(&existing).Error; err != nil {
		Information.Error = err.Error()
		Information.Status = http.StatusConflict
		return Information, errors.New(dbError)
	}

	Information.Entries = []Cert{existing}
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
