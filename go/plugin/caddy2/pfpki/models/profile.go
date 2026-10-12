package models

import (
	"encoding/json"
	"errors"
	"strings"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
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

	if err := p.DB.Create(&profile).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}

	// The INSERT replaced the fields sent as 0 (EAB off, no renewal
	// mail, renewal always allowed, ...) by their database default:
	// store the values the request asked for.
	requested := p.defaultedFields()
	zeroed := map[string]interface{}{}
	for column, stored := range profile.defaultedFields() {
		if p.sentFields[column] && *stored != *requested[column] {
			*stored = *requested[column]
			zeroed[column] = *stored
		}
	}
	if len(zeroed) > 0 {
		if err := p.DB.Model(&profile).Updates(zeroed).Error; err != nil {
			Information.Error = err.Error()
			return Information, errors.New(dbError)
		}
	}
	Information.Entries = []Profile{profile}

	return Information, nil
}

func (p Profile) Update(params map[string]string) (types.Info, error) {
	var profiledb []Profile
	Information := types.Info{}
	scepserver := &SCEPServer{}

	profile := &Profile{}

	// Choose the default scep server in the db
	if p.ScepServerID == 0 {
		p.ScepServerID = 1
	}

	if err := p.DB.First(scepserver, p.ScepServerID).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}

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

	// Copy every user-mutable field from the request body onto the loaded
	// row. Fields that aren't listed here (Name, CaID, CaName, IDs,
	// timestamps) are intentionally preserved from the DB copy.
	profile.Mail = p.Mail
	profile.Organisation = p.Organisation
	profile.OrganisationalUnit = p.OrganisationalUnit
	profile.Country = p.Country
	profile.State = p.State
	profile.Locality = p.Locality
	profile.StreetAddress = p.StreetAddress
	profile.PostalCode = p.PostalCode
	profile.Validity = p.Validity
	profile.KeyUsage = p.KeyUsage
	profile.ExtendedKeyUsage = p.ExtendedKeyUsage
	profile.OCSPUrl = p.OCSPUrl
	profile.P12MailPassword = p.P12MailPassword
	profile.P12MailSubject = p.P12MailSubject
	profile.P12MailFrom = p.P12MailFrom
	profile.P12MailHeader = p.P12MailHeader
	profile.P12MailFooter = p.P12MailFooter
	profile.SCEPEnabled = p.SCEPEnabled
	profile.SCEPChallengePassword = p.SCEPChallengePassword
	profile.SCEPDaysBeforeRenewal = p.SCEPDaysBeforeRenewal
	profile.DaysBeforeRenewal = p.DaysBeforeRenewal
	profile.RenewalMail = p.RenewalMail
	profile.DaysBeforeRenewalMail = p.DaysBeforeRenewalMail
	profile.RenewalMailSubject = p.RenewalMailSubject
	profile.RenewalMailFrom = p.RenewalMailFrom
	profile.RenewalMailHeader = p.RenewalMailHeader
	profile.RenewalMailFooter = p.RenewalMailFooter
	profile.RevokedValidUntil = p.RevokedValidUntil
	profile.CloudEnabled = p.CloudEnabled
	profile.CloudService = p.CloudService
	profile.ScepServerEnabled = p.ScepServerEnabled
	profile.AllowDuplicatedCN = p.AllowDuplicatedCN
	profile.MaximumDuplicatedCN = p.MaximumDuplicatedCN
	profile.AcmeEnabled = p.AcmeEnabled
	profile.AcmeAllowedIdentifiers = p.AcmeAllowedIdentifiers
	profile.AcmeEabRequired = p.AcmeEabRequired
	profile.AcmeAttestationFormats = p.AcmeAttestationFormats
	profile.AcmeAttestationRoots = p.AcmeAttestationRoots
	profile.AcmeAccountExpiry = p.AcmeAccountExpiry
	profile.AcmeOrderExpiry = p.AcmeOrderExpiry
	profile.AcmeAuthzExpiry = p.AcmeAuthzExpiry
	profile.EstEnabled = p.EstEnabled
	profile.EstUsername = p.EstUsername
	profile.EstPassword = p.EstPassword
	profile.ScepServer = *scepserver

	p.DB.Save(&profile)

	profiledb = append(profiledb, p)
	Information.Entries = profiledb

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

