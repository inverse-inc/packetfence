package models

import (
	"encoding/json"
	"errors"
	"strings"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// UnmarshalJSON decodes a profile and records which fields the request
// sent, so New can tell a field sent as 0 from a missing one.
func (p *Profile) UnmarshalJSON(data []byte) error {
	type plain Profile
	if err := json.Unmarshal(data, (*plain)(p)); err != nil {
		return err
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil {
		return err
	}
	p.sentFields = make(map[string]bool, len(fields))
	for k := range fields {
		p.sentFields[k] = true
	}
	return nil
}

// defaultedFields returns the profile columns that have a non-zero
// database default, with a pointer to their value. gorm leaves a zero
// value out of an INSERT, so the database default would replace it.
func (p *Profile) defaultedFields() map[string]*int {
	return map[string]*int{
		"scep_days_before_renewal": &p.SCEPDaysBeforeRenewal,
		"days_before_renewal":      &p.DaysBeforeRenewal,
		"renewal_mail":             &p.RenewalMail,
		"days_before_renewal_mail": &p.DaysBeforeRenewalMail,
		"revoked_valid_until":      &p.RevokedValidUntil,
		"acme_eab_required":        &p.AcmeEabRequired,
		"acme_account_expiry":      &p.AcmeAccountExpiry,
		"acme_order_expiry":        &p.AcmeOrderExpiry,
		"acme_authz_expiry":        &p.AcmeAuthzExpiry,
	}
}

// Profile section
func NewProfileModel(pfpki *types.Handler) *Profile {
	Profile := &Profile{}

	Profile.DB = pfpki.DB
	Profile.Ctx = *pfpki.Ctx

	return Profile
}

func (p Profile) New() (types.Info, error) {

	var err error
	Information := types.Info{}
	switch *p.KeyType {
	case certutils.KEY_RSA:
		if p.KeySize < 2048 {
			err = errors.New("invalid private key size, should be at least 2048")
			Information.Error = err.Error()
			return Information, err
		}
	case certutils.KEY_ECDSA:
		if !(p.KeySize == 256 || p.KeySize == 384 || p.KeySize == 521) {
			err = errors.New("invalid private key size, should be 256 or 384 or 521")
			Information.Error = err.Error()
			return Information, err
		}
	case certutils.KEY_DSA:
		if !(p.KeySize == 1024 || p.KeySize == 2048 || p.KeySize == 3072) {
			err = errors.New("invalid private key size, should be 1024 or 2048 or 3072")
			Information.Error = err.Error()
			return Information, err
		}
	case certutils.KEY_ED25519:
		// Ed25519 has a fixed key size; ignore p.KeySize.
	default:
		return Information, errors.New("KeyType unsupported")

	}

	ca := &CA{}

	if err := p.DB.First(ca, p.CaID).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	scepserver := &SCEPServer{}
	// Choose the default scep server in the db
	if p.ScepServerID == 0 {
		p.ScepServerID = 1
	}

	if err := p.DB.First(scepserver, p.ScepServerID).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	// Copy the receiver and override the few fields the request body
	// can't have (the FK back-references and the loaded CA struct).
	profile := p
	profile.ID = 0
	profile.Ca = *ca
	profile.CaName = ca.Cn

	// The INSERT replaces the fields sent as 0 (EAB off, no renewal
	// mail, renewal always allowed, ...) by their database default, so
	// the values the request asked for are written right after, in the
	// same transaction: the profile is never seen with the defaults.
	err = p.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&profile).Error; err != nil {
			return err
		}
		requested := p.defaultedFields()
		zeroed := map[string]interface{}{}
		for column, stored := range profile.defaultedFields() {
			if p.sentFields[column] && *stored != *requested[column] {
				*stored = *requested[column]
				zeroed[column] = *stored
			}
		}
		if len(zeroed) > 0 {
			return tx.Model(&profile).Updates(zeroed).Error
		}
		return nil
	})
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}
	Information.Entries = []Profile{profile}

	return Information, nil
}

func (p Profile) Update(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	scepserver := &SCEPServer{}

	profile := &Profile{}

	if val, ok := params["id"]; ok {
		if err := p.DB.First(profile, val).Error; err != nil {
			Information.Error = err.Error()
			return Information, err
		}
	} else {
		if err := p.DB.Where("name = ?", p.Name).First(profile).Error; err != nil {
			Information.Error = err.Error()
			return Information, err
		}
	}

	// Copy the user-mutable fields the request sent onto the loaded row,
	// so a PATCH leaves the fields it omits unchanged (every field is
	// copied when the profile wasn't decoded from JSON). Fields that
	// aren't listed here (Name, CaID, CaName, IDs, timestamps) are
	// always preserved from the DB copy.
	sent := func(field string) bool {
		return p.sentFields == nil || p.sentFields[field]
	}
	for field, apply := range map[string]func(){
		"mail":                     func() { profile.Mail = p.Mail },
		"organisation":             func() { profile.Organisation = p.Organisation },
		"organisational_unit":      func() { profile.OrganisationalUnit = p.OrganisationalUnit },
		"country":                  func() { profile.Country = p.Country },
		"state":                    func() { profile.State = p.State },
		"locality":                 func() { profile.Locality = p.Locality },
		"street_address":           func() { profile.StreetAddress = p.StreetAddress },
		"postal_code":              func() { profile.PostalCode = p.PostalCode },
		"validity":                 func() { profile.Validity = p.Validity },
		"key_usage":                func() { profile.KeyUsage = p.KeyUsage },
		"extended_key_usage":       func() { profile.ExtendedKeyUsage = p.ExtendedKeyUsage },
		"ocsp_url":                 func() { profile.OCSPUrl = p.OCSPUrl },
		"p12_mail_password":        func() { profile.P12MailPassword = p.P12MailPassword },
		"p12_mail_subject":         func() { profile.P12MailSubject = p.P12MailSubject },
		"p12_mail_from":            func() { profile.P12MailFrom = p.P12MailFrom },
		"p12_mail_header":          func() { profile.P12MailHeader = p.P12MailHeader },
		"p12_mail_footer":          func() { profile.P12MailFooter = p.P12MailFooter },
		"scep_enabled":             func() { profile.SCEPEnabled = p.SCEPEnabled },
		"scep_challenge_password":  func() { profile.SCEPChallengePassword = p.SCEPChallengePassword },
		"scep_days_before_renewal": func() { profile.SCEPDaysBeforeRenewal = p.SCEPDaysBeforeRenewal },
		"days_before_renewal":      func() { profile.DaysBeforeRenewal = p.DaysBeforeRenewal },
		"renewal_mail":             func() { profile.RenewalMail = p.RenewalMail },
		"days_before_renewal_mail": func() { profile.DaysBeforeRenewalMail = p.DaysBeforeRenewalMail },
		"renewal_mail_days":        func() { profile.RenewalMailDays = p.RenewalMailDays },
		"renewal_mail_subject":     func() { profile.RenewalMailSubject = p.RenewalMailSubject },
		"renewal_mail_from":        func() { profile.RenewalMailFrom = p.RenewalMailFrom },
		"renewal_mail_header":      func() { profile.RenewalMailHeader = p.RenewalMailHeader },
		"renewal_mail_footer":      func() { profile.RenewalMailFooter = p.RenewalMailFooter },
		"revoked_valid_until":      func() { profile.RevokedValidUntil = p.RevokedValidUntil },
		"cloud_enabled":            func() { profile.CloudEnabled = p.CloudEnabled },
		"cloud_service":            func() { profile.CloudService = p.CloudService },
		"scep_server_enabled":      func() { profile.ScepServerEnabled = p.ScepServerEnabled },
		"scep_server_id":           func() { profile.ScepServerID = p.ScepServerID },
		"allow_duplicated_cn":      func() { profile.AllowDuplicatedCN = p.AllowDuplicatedCN },
		"maximum_duplicated_cn":    func() { profile.MaximumDuplicatedCN = p.MaximumDuplicatedCN },
		"acme_enabled":             func() { profile.AcmeEnabled = p.AcmeEnabled },
		"acme_allowed_identifiers": func() { profile.AcmeAllowedIdentifiers = p.AcmeAllowedIdentifiers },
		"acme_eab_required":        func() { profile.AcmeEabRequired = p.AcmeEabRequired },
		"acme_attestation_formats": func() { profile.AcmeAttestationFormats = p.AcmeAttestationFormats },
		"acme_attestation_roots":   func() { profile.AcmeAttestationRoots = p.AcmeAttestationRoots },
		"acme_account_expiry":      func() { profile.AcmeAccountExpiry = p.AcmeAccountExpiry },
		"acme_order_expiry":        func() { profile.AcmeOrderExpiry = p.AcmeOrderExpiry },
		"acme_authz_expiry":        func() { profile.AcmeAuthzExpiry = p.AcmeAuthzExpiry },
		"est_enabled":              func() { profile.EstEnabled = p.EstEnabled },
		"est_username":             func() { profile.EstUsername = p.EstUsername },
		"est_password":             func() { profile.EstPassword = p.EstPassword },
	} {
		if sent(field) {
			apply()
		}
	}

	// Choose the default scep server in the db
	if profile.ScepServerID == 0 {
		profile.ScepServerID = 1
	}
	if err := p.DB.First(scepserver, profile.ScepServerID).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	profile.ScepServer = *scepserver

	if err := p.DB.Save(profile).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}

	Information.Entries = []Profile{*profile}

	return Information, nil
}

func (p Profile) GetByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var profiledb []Profile
	if val, ok := params["id"]; ok {
		allFields := strings.Join(sql.SqlFields(p)[:], ",")
		p.DB.Select(allFields).Where("`id` = ?", val).First(&profiledb)
	}
	Information.Entries = profiledb

	return Information, nil
}

func (p Profile) Paginated(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int64
	p.DB.Model(&Profile{}).Count(&count)
	counter := int(count)

	Information.TotalCount = counter
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < counter {
		sql, err := vars.Sql(p)
		if err != nil {
			Information.Error = err.Error()
			return Information, errors.New(dbError)
		}
		var profiledb []Profile
		p.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&profiledb)
		Information.Entries = profiledb
	}

	return Information, nil
}

func (p Profile) Search(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(p)
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}
	var count int64
	p.DB.Model(&Profile{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	counter := int(count)
	Information.TotalCount = counter
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < counter {
		var profiledb []Profile
		p.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&profiledb)
		Information.Entries = profiledb
	}

	return Information, nil
}

