package models

import (
	"bytes"
	"context"
	"crypto/rand"
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
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/cloud"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"golang.org/x/crypto/ocsp"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
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
	// Load the CA certificate and key
	cacert, cakey, err := prof.Ca.KeyPair(c.DB)
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
	certByte, err := x509.CreateCertificate(rand.Reader, cert, cacert, pub, cakey)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	certBuff := new(bytes.Buffer)

	// Public key
	pem.Encode(certBuff, &pem.Block{Type: "CERTIFICATE", Bytes: certByte})

	// Build the row from explicit fields: request-only state (date, scep,
	// alert, alerted_days, ...) must not be persisted from the body.
	newCert := Cert{
		Cn:                 c.Cn,
		Ca:                 prof.Ca,
		CaID:               prof.Ca.ID,
		CaName:             prof.Ca.Cn,
		Profile:            prof,
		ProfileID:          prof.ID,
		ProfileName:        prof.Name,
		SerialNumber:       SerialNumber.String(),
		DNSNames:           c.DNSNames,
		IPAddresses:        strings.Join(IPAddresses, ","),
		Mail:               Email,
		StreetAddress:      strings.Join(Subject.StreetAddress, ""),
		Organisation:       strings.Join(Subject.Organization, ""),
		OrganisationalUnit: strings.Join(Subject.OrganizationalUnit, ""),
		Country:            strings.Join(Subject.Country, ""),
		State:              strings.Join(Subject.Province, ""),
		Locality:           strings.Join(Subject.Locality, ""),
		PostalCode:         strings.Join(Subject.PostalCode, ""),
		Key:                keyOut.String(),
		Cert:               certBuff.String(),
		ValidUntil:         cert.NotAfter,
		NotBefore:          cert.NotBefore,
		Subject:            Subject.String(),
	}
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

	// Load the CA certificate for the chain
	cacert, err := cert.Ca.Certificate()
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

	if cert.ID == 0 {
		Information.Error = "Certificate not found"
		return Information, errors.New("Certificate not found")
	}

	intreason, err := strconv.Atoi(reason)
	if err != nil {
		Information.Error = "Reason unsupported"
		return Information, errors.New("Reason unsupported")
	}

	// A superseded certificate stays valid (OCSP good) for the profile's
	// RevokedValidUntil days, so a device keeps working until it has
	// installed its new certificate. Any other reason (key compromise,
	// ...) takes effect at once.
	RevokeDate := time.Now()
	if intreason == ocsp.Superseded {
		var profile Profile
		if err := c.DB.First(&profile, cert.ProfileID).Error; err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			Information.Error = err.Error()
			return Information, err
		}
		RevokeDate = RevokeDate.AddDate(0, 0, profile.RevokedValidUntil)
		// The grace period never outlives the certificate.
		if RevokeDate.After(cert.ValidUntil) {
			RevokeDate = time.Now()
			if cert.ValidUntil.After(RevokeDate) {
				RevokeDate = cert.ValidUntil
			}
		}
	}
	revoked := RevokedCert{Cn: cert.Cn, Mail: cert.Mail, CaID: cert.CaID, CaName: cert.CaName, StreetAddress: cert.StreetAddress, Organisation: cert.Organisation, OrganisationalUnit: cert.OrganisationalUnit, Country: cert.Country, State: cert.State, Locality: cert.Locality, PostalCode: cert.PostalCode, Key: cert.Key, Cert: cert.Cert, ProfileID: cert.ProfileID, ProfileName: cert.ProfileName, ValidUntil: cert.ValidUntil, NotBefore: cert.NotBefore, Date: cert.Date, Revoked: RevokeDate, CRLReason: intreason, SerialNumber: cert.SerialNumber, DNSNames: cert.DNSNames, IPAddresses: cert.IPAddresses, Subject: cert.Subject}
	// Move the row: a certificate is either live or revoked, never both
	// or neither.
	if err := c.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Omit(clause.Associations).Create(&revoked).Error; err != nil {
			return err
		}
		return tx.Unscoped().Delete(&Cert{}, cert.ID).Error
	}); err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	return Information, nil
}

// AcmeIdentifier is the lightweight (type, value) pair the ACME layer
// hands to SignCSRForACME. It mirrors the on-the-wire shape so we
// don't have to import the acme package back into models.
type AcmeIdentifier struct {
	Type  string
	Value string
}

// ValidateACMECSR enforces RFC 8555 §7.4 on a finalize CSR: every name
// the certificate would carry must be an identifier the order was
// authorized for. The CSR may use a strict subset (some clients drop
// SANs they no longer want) but any name not in the order is a hard
// reject — this is the security boundary that prevents a device that
// proved ownership of example.com from minting a cert for
// example.bank, or from adding an email / URI SAN it never proved.
//
//   - CN:           a dns (case-insensitive), ip or permanent-identifier
//   - DNS SANs:     dns identifiers
//   - IP SANs:      ip identifiers
//   - email SANs:   email identifiers (none can be ordered today)
//   - URI SANs:     always rejected, ACME has no URI identifier type
//
// Other Subject attributes are ignored here: SignCSRForACME takes them
// from the profile, never from the CSR.
func ValidateACMECSR(csr *x509.CertificateRequest, identifiers []AcmeIdentifier) error {
	var dns, ip, email, permanent []string
	for _, id := range identifiers {
		switch id.Type {
		case "dns":
			dns = append(dns, id.Value)
		case "ip":
			ip = append(ip, id.Value)
		case "email":
			email = append(email, id.Value)
		case "permanent-identifier":
			permanent = append(permanent, id.Value)
		}
	}
	if cn := strings.TrimSpace(csr.Subject.CommonName); cn != "" {
		if !containsFold(dns, cn) && !containsString(ip, cn) && !containsString(permanent, cn) {
			return fmt.Errorf("CSR CN %q not in order identifiers", cn)
		}
	}
	for _, name := range csr.DNSNames {
		if !containsFold(dns, name) {
			return fmt.Errorf("CSR DNS SAN %q not in order identifiers", name)
		}
	}
	for _, addr := range csr.IPAddresses {
		if !containsString(ip, addr.String()) {
			return fmt.Errorf("CSR IP SAN %q not in order identifiers", addr.String())
		}
	}
	for _, mail := range csr.EmailAddresses {
		if !containsFold(email, mail) {
			return fmt.Errorf("CSR email SAN %q not in order identifiers", mail)
		}
	}
	if len(csr.URIs) > 0 {
		return fmt.Errorf("CSR URI SAN %q not allowed", csr.URIs[0].String())
	}
	return nil
}

// SignCSRForACME issues a cert against the given profile for an
// ACME-finalize call. It is the single integration point between the
// ACME server and pfpki issuance: the CSR is validated against the
// order's identifiers (ValidateACMECSR), the Subject is built from the
// profile the way SCEP / admin issuance does (only the CN comes from
// the CSR), then the cert is signed with the profile's CA and persisted
// to pki_certs with accountID as its ACME owner.
//
// Returns the newly-inserted Cert row (with ID + SerialNumber
// populated) or an error suitable for an ACME problem document.
//
// Callers must hand a profile loaded with `Preload("Ca")` so the CA
// cert/key are accessible.
func SignCSRForACME(db *gorm.DB, ctx context.Context, prof Profile, csrDER []byte, identifiers []AcmeIdentifier, accountID uint) (*Cert, error) {
	csr, err := x509.ParseCertificateRequest(csrDER)
	if err != nil {
		return nil, fmt.Errorf("parse CSR: %w", err)
	}
	if err := csr.CheckSignature(); err != nil {
		return nil, fmt.Errorf("CSR self-signature: %w", err)
	}
	if err := ValidateACMECSR(csr, identifiers); err != nil {
		return nil, err
	}
	return issueFromCSR(db, ctx, prof, csr, accountID)
}

// issueFromCSR signs csr with the profile's CA and persists the result
// to pki_certs. The Subject is built from the profile (only the CN comes
// from the CSR) and the SANs are copied from the CSR, so callers must
// have validated them first. Shared by ACME finalize and EST enrollment.
func issueFromCSR(db *gorm.DB, ctx context.Context, prof Profile, csr *x509.CertificateRequest, accountID uint) (*Cert, error) {
	// Atomically allocate a serial.
	serial, err := nextSerialNumber(db, prof.Ca.ID, false)
	if err != nil {
		return nil, fmt.Errorf("allocate serial: %w", err)
	}

	// Skid is computed from the CSR's pubkey, not the CA's, so each
	// issued leaf has its own SubjectKeyIdentifier.
	skid, err := certutils.CalculateSKID(csr.PublicKey)
	if err != nil {
		return nil, fmt.Errorf("compute SKID: %w", err)
	}

	// Build the cert template. Subject attributes, KeyUsage,
	// ExtKeyUsage and Digest come from the profile, just like the
	// existing CSR.New path; the CSR only contributes the CN and the
	// validated SANs.
	attributes := ProfileAttributes(prof)
	subject := certutils.MakeSubject(pkix.Name{}, attributes)
	subject.CommonName = strings.TrimSpace(csr.Subject.CommonName)
	keyUsage := x509.KeyUsage(certutils.Keyusage(strings.Split(strDeref(prof.KeyUsage), "|")))
	extKeyUsage := certutils.Extkeyusage(strings.Split(strDeref(prof.ExtendedKeyUsage), "|"))

	tmpl := &x509.Certificate{
		SerialNumber:       serial,
		Subject:            subject,
		NotBefore:          time.Now().UTC(),
		NotAfter:           time.Now().AddDate(0, 0, prof.Validity).UTC(),
		SignatureAlgorithm: certutils.CompatibleSigAlgo(*prof.Ca.KeyType, prof.Digest),
		KeyUsage:           keyUsage,
		ExtKeyUsage:        extKeyUsage,
		SubjectKeyId:       skid,
		DNSNames:           csr.DNSNames,
		IPAddresses:        csr.IPAddresses,
		EmailAddresses:     csr.EmailAddresses,
	}
	if prof.OCSPUrl != "" {
		tmpl.OCSPServer = []string{prof.OCSPUrl}
	}

	cacert, cakey, err := prof.Ca.KeyPair(db)
	if err != nil {
		return nil, fmt.Errorf("load CA key pair: %w", err)
	}
	derBytes, err := x509.CreateCertificate(rand.Reader, tmpl, cacert, csr.PublicKey, cakey)
	if err != nil {
		return nil, fmt.Errorf("sign cert: %w", err)
	}
	pemBuf := new(bytes.Buffer)
	if err := pem.Encode(pemBuf, &pem.Block{Type: "CERTIFICATE", Bytes: derBytes}); err != nil {
		return nil, err
	}

	dnMap := certutils.GetDNFromCert(subject)
	cnForRow := subject.CommonName
	if cnForRow == "" {
		// ACME profiles often issue with empty CN + only SANs; pick
		// the first DNS SAN for the row's index column.
		if len(csr.DNSNames) > 0 {
			cnForRow = csr.DNSNames[0]
		} else if len(csr.IPAddresses) > 0 {
			cnForRow = csr.IPAddresses[0].String()
		}
	}

	var ipStrings []string
	for _, ip := range csr.IPAddresses {
		ipStrings = append(ipStrings, ip.String())
	}

	notfalse := false
	notTrue := true
	row := Cert{
		Cn:                 cnForRow,
		Mail:               strings.Join(csr.EmailAddresses, ","),
		Ca:                 prof.Ca,
		CaID:               prof.Ca.ID,
		CaName:             prof.Ca.Cn,
		StreetAddress:      dnMap["streetAddress"],
		Organisation:       dnMap["O"],
		OrganisationalUnit: dnMap["OU"],
		Country:            dnMap["C"],
		State:              dnMap["ST"],
		Locality:           dnMap["L"],
		PostalCode:         dnMap["postalCode"],
		Cert:               pemBuf.String(),
		Profile:            prof,
		ProfileID:          prof.ID,
		ProfileName:        prof.Name,
		ValidUntil:         tmpl.NotAfter,
		NotBefore:          tmpl.NotBefore,
		SerialNumber:       serial.String(),
		DNSNames:           strings.Join(csr.DNSNames, ","),
		IPAddresses:        strings.Join(ipStrings, ","),
		Scep:               &notfalse,
		Csr:                &notTrue,
		Subject:            subject.String(),
		AcmeAccountID:      accountID,
		DB:                 db,
		Ctx:                ctx,
	}
	if err := db.Create(&row).Error; err != nil {
		return nil, fmt.Errorf("persist cert: %w", err)
	}
	return &row, nil
}

func strDeref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

// containsString is the trivial linear-scan membership test used by
// SignCSRForACME's identifier validation. Tiny lists (1-5 names), so
// the obvious O(n*m) check is fine.
func containsString(xs []string, want string) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}

// containsFold is containsString for DNS names and mail addresses,
// where case is not significant.
func containsFold(xs []string, want string) bool {
	for _, x := range xs {
		if strings.EqualFold(x, want) {
			return true
		}
	}
	return false
}

// serialCandidates returns the stored forms a serial presented by an
// external system may correspond to. pki_certs stores big.Int.String()
// (decimal), while Intune and most X.509 tooling show hex, sometimes
// with colon or space separators or a 0x prefix.
//
// Every decimal string is also valid hex, so the input is read as hex
// only when it can't be decimal: a 0x prefix, separators or an a-f
// digit. "100" is serial 100, never also 0x100 (256): matching both
// would let a revocation for one device hit another device's cert.
func serialCandidates(serial string) []string {
	s := strings.TrimSpace(serial)
	if s == "" {
		return nil
	}
	seen := map[string]bool{}
	var out []string
	add := func(v string) {
		if v != "" && !seen[v] {
			seen[v] = true
			out = append(out, v)
		}
	}
	add(s)
	if !serialLooksHex(s) {
		if n, ok := new(big.Int).SetString(s, 10); ok {
			add(n.String())
		}
		return out
	}
	h := strings.NewReplacer(":", "", " ", "", "-", "").Replace(s)
	h = strings.TrimPrefix(strings.TrimPrefix(h, "0x"), "0X")
	if n, ok := new(big.Int).SetString(h, 16); ok {
		add(n.String())
	}
	return out
}

// serialLooksHex tells whether a serial can only be read as hex.
func serialLooksHex(s string) bool {
	if strings.HasPrefix(s, "0x") || strings.HasPrefix(s, "0X") || strings.ContainsAny(s, ": -") {
		return true
	}
	return strings.ContainsAny(s, "abcdefABCDEF")
}

// RevokeBySerial looks up a leaf by serial number under the given CA
// name and revokes it with the supplied reason. Returns true when a
// matching cert was found and revoked, false when no row matched (which
// is not an error — the cloud-side revocation may target a cert that
// pfpki already revoked or never issued, and we want the upstream
// acknowledgement to record that as "succeeded" rather than retrying
// forever).
func (c Cert) RevokeBySerial(caName, serial string, reason int) (bool, error) {
	var cert Cert
	q := c.DB.Where("ca_name = ? AND serial_number IN ?", caName, serialCandidates(serial)).First(&cert)
	if q.Error != nil {
		if errors.Is(q.Error, gorm.ErrRecordNotFound) {
			return false, nil
		}
		return false, q.Error
	}
	cert.DB = c.DB
	cert.Ctx = c.Ctx
	if _, err := cert.Revoke(map[string]string{
		"id":     strconv.Itoa(int(cert.ID)),
		"reason": strconv.Itoa(reason),
	}); err != nil {
		return false, err
	}
	return true, nil
}

// isDuplicateSubjectError detects the "Certificate with this Subject
// already exist" guard rail raised by revokeNeeded. We match on prefix
// so the wrapped error from errors.New keeps working without exporting
// a sentinel; if revokeNeeded gets a refactor someday this matcher is
// the one place to update.
func isDuplicateSubjectError(err error) bool {
	if err == nil {
		return false
	}
	return strings.HasPrefix(err.Error(), "Certificate with this Subject already exist")
}

// drainCloudRevocations downloads any pending revocations the cloud
// provider has queued for prof.Ca and applies them locally. Returns the
// number of revocations that resulted in a matching pfpki cert being
// revoked. It runs from the pki_process_cloud_revocations task and the
// manual endpoint only: Intune's 60-minute cool-down after each
// download makes it useless on the SCEP request path, which handles
// re-enrollment by superseding (see CA.HasCN).
//
// All error paths log and return 0.
func drainCloudRevocations(ctx context.Context, prof Profile, db *gorm.DB) int {
	vcloud, err := cloud.Create(ctx, "intune", prof.CloudService)
	if err != nil {
		log.LoggerWContext(ctx).Warn("drainCloudRevocations: cloud.Create: " + err.Error())
		return 0
	}
	rp, ok := vcloud.(cloud.RevocationProcessor)
	if !ok {
		return 0
	}
	helper := Cert{DB: db, Ctx: ctx}
	var localApplied int
	revoke := func(ctx context.Context, req cloud.RevocationRequest) cloud.RevocationResult {
		// The queue was requested for prof.Ca by name, so that is the
		// CA to match on; Intune's issuerName is a full DN, not the
		// ca_name column value.
		found, err := helper.RevokeBySerial(prof.Ca.Cn, req.SerialNumber, cloudRevocationReason)
		switch {
		case err != nil:
			log.LoggerWContext(ctx).Error("drainCloudRevocations: " + err.Error())
			return cloud.RevocationResult{RequestID: req.RequestID, Succeeded: false,
				ErrorCode: cloud.CARequestErrorRetryable, ErrorMessage: err.Error()}
		case found:
			localApplied++
			return cloud.RevocationResult{RequestID: req.RequestID, Succeeded: true}
		}
		// No live cert matched. If it is already in pki_revoked_certs
		// the request is satisfied; otherwise report a failure so
		// Intune keeps the item visible instead of us silently
		// discarding a revocation we never applied.
		var revokedCount int64
		_ = db.Model(&RevokedCert{}).
			Where("ca_name = ? AND serial_number IN ?", prof.Ca.Cn, serialCandidates(req.SerialNumber)).
			Count(&revokedCount).Error
		if revokedCount > 0 {
			return cloud.RevocationResult{RequestID: req.RequestID, Succeeded: true}
		}
		msg := fmt.Sprintf("certificate serial %s not found under CA %q in PacketFence PKI (issuer %q)",
			req.SerialNumber, prof.Ca.Cn, req.IssuerName)
		log.LoggerWContext(ctx).Warn("drainCloudRevocations: " + msg)
		return cloud.RevocationResult{RequestID: req.RequestID, Succeeded: false,
			ErrorCode: cloud.CARequestErrorCertificateNotFound, ErrorMessage: msg}
	}
	if _, err := rp.ProcessRevocations(ctx, prof.Ca.Cn, revoke); err != nil {
		log.LoggerWContext(ctx).Warn("drainCloudRevocations: ProcessRevocations: " + err.Error())
	}
	return localApplied
}

// cloudRevocationReason is the RFC 5280 CRLReason recorded for a
// revocation pulled from the cloud queue. Intune's feed carries no
// reason, so "unspecified" (0) is the only honest value.
const cloudRevocationReason = 0

// ProcessCloudRevocations iterates every cloud-enabled profile and asks
// its provider for any pending revocation requests, applying them
// locally. Returns the total number of local revocations applied (the
// number reported in Information.TotalCount), so a caller / operator
// can confirm progress on a manual trigger.
func (c Cert) ProcessCloudRevocations() (types.Info, error) {
	Information := types.Info{}

	var profiles []Profile
	if err := c.DB.Preload("Ca").Where("cloud_enabled = ?", 1).Find(&profiles).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	applied := 0
	for _, prof := range profiles {
		applied += drainCloudRevocations(c.Ctx, prof, c.DB)
	}
	Information.TotalCount = applied
	return Information, nil
}

func (c Cert) CheckRenewal(params map[string]string) (types.Info, error) {
	Information := types.Info{}

	// Load the profiles once per run, and the largest renewal-mail
	// threshold among them: only the certificates within that many days
	// of their expiry (the expired ones included) need a look.
	var profiles []Profile
	if ProfDB := c.DB.Find(&profiles); ProfDB.Error != nil {
		Information.Error = ProfDB.Error.Error()
		return Information, ProfDB.Error
	}
	profByID := make(map[uint]Profile, len(profiles))
	maxDays := 0
	for _, prof := range profiles {
		profByID[prof.ID] = prof
		if prof.RenewalMail != 1 {
			continue
		}
		thresholds, _ := parseRenewalThresholds(prof)
		for _, T := range thresholds {
			if T > maxDays {
				maxDays = T
			}
		}
	}

	now := time.Now()
	var certdb []Cert
	if CertDB := c.DB.Where("valid_until <= ?", now.AddDate(0, 0, maxDays)).Find(&certdb); CertDB.Error != nil {
		Information.Error = CertDB.Error.Error()
		return Information, CertDB.Error
	}

	for _, v := range certdb {
		// Revoke due certificate
		if now.Unix() > v.ValidUntil.Unix() {
			c.Revoke(map[string]string{
				"id":     strconv.Itoa(int(v.ID)),
				"reason": strconv.Itoa(ocsp.Superseded),
			})
			continue
		}

		prof, ok := profByID[v.ProfileID]
		if !ok {
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

		if _, err := sendRenewalMail(c.Ctx, v, prof); err != nil {
			log.LoggerWContext(c.Ctx).Error(fmt.Sprintf("renewal mail for cert %d failed: %v", v.ID, err))
			continue
		}

		if fallbackOneShot {
			notfalse := true
			v.Alert = &notfalse
		} else {
			// The mail for the closest threshold replaces the ones for
			// the larger thresholds: never send them late.
			thresholds, _ := parseRenewalThresholds(prof)
			for _, T := range thresholds {
				if T >= due {
					v.AlertedDays = appendAlertedDay(v.AlertedDays, T)
				}
			}
		}
		state := map[string]interface{}{"alerted_days": v.AlertedDays}
		if fallbackOneShot {
			state = map[string]interface{}{"alert": true}
		}
		if err := c.DB.Model(&Cert{}).Where("id = ?", v.ID).Updates(state).Error; err != nil {
			log.LoggerWContext(c.Ctx).Error(fmt.Sprintf("persist alert state for cert %d failed: %v", v.ID, err))
		}
	}

	return Information, nil
}

// sendRenewalMail sends the renewal mail of a certificate (replaced in
// tests).
var sendRenewalMail = emailRenewal

// nextDueRenewalThreshold returns the threshold in days for which a
// renewal email should be sent now: the smallest (most-imminent) crossed
// threshold, unless its mail was already sent. -1 means nothing is due.
// The caller marks the larger thresholds as sent along with it, so a
// mail for a larger threshold is never sent after a smaller one.
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
	// Only the smallest crossed threshold counts: one mail per cron tick,
	// not a backlog, and never one for a larger threshold after it.
	for _, T := range thresholds {
		if !thresholdCrossed(now, cert.ValidUntil, T) {
			continue
		}
		if already[T] {
			return -1, false
		}
		return T, false
	}
	return -1, false
}

// thresholdCrossed reports whether `now` is within `T` days of NotAfter.
func thresholdCrossed(now, notAfter time.Time, T int) bool {
	return now.Add(time.Duration(T)*24*time.Hour).After(notAfter) ||
		now.Add(time.Duration(T)*24*time.Hour).Equal(notAfter)
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

	cacert, cakey, err := existing.Ca.KeyPair(c.DB)
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

	certBytes, err := x509.CreateCertificate(rand.Reader, tmpl, cacert, pub, cakey)
	if err != nil {
		return Information, err
	}

	certBuff := new(bytes.Buffer)
	pem.Encode(certBuff, &pem.Block{Type: "CERTIFICATE", Bytes: certBytes})

	// Update the existing row by primary key — the previous WHERE cn = ?
	// match was fragile when the request body omitted Cn (a "click and
	// renew" with no edits) and could silently update nothing.
	existing.SerialNumber = SerialNumber.String()
	// The new validity window gets its own renewal mails.
	notAlerted := false
	existing.Alert = &notAlerted
	existing.AlertedDays = ""
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
