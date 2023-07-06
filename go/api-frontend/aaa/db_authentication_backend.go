package aaa

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/go-utils/sharedutils"
)

type DbAuthenticationBackend struct {
	db        *sql.DB
	tableName string
}

type ApiUser struct {
	Username    string
	Password    string
	ValidFrom   time.Time
	Expiration  time.Time
	AccessLevel string
	TenantId    int
}

func NewDbAuthenticationBackend(ctx context.Context, db *sql.DB, tableName string) *DbAuthenticationBackend {
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.AdminRoles)

	return &DbAuthenticationBackend{
		db:        db,
		tableName: tableName,
	}
}

func (dab *DbAuthenticationBackend) SetUser(ctx context.Context, apiUser *ApiUser) error {
	query := fmt.Sprintf("replace into %s (username, password, valid_from, expiration, access_level, tenant_id) values(?, ?, ?, ?, ?, ?)", dab.tableName)

	bcryptBytes, err := bcrypt.GenerateFromPassword([]byte(apiUser.Password), bcrypt.DefaultCost)
	sharedutils.CheckError(err)
	apiUser.Password = string(bcryptBytes)

	_, err = dab.db.Query(query, apiUser.Username, apiUser.Password, apiUser.ValidFrom, apiUser.Expiration, apiUser.AccessLevel, apiUser.TenantId)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while setting user %s", err))
		return err
	}

	return nil
}

func (dab *DbAuthenticationBackend) Authenticate(ctx context.Context, username, password string) (bool, *TokenInfo, error) {
	query := fmt.Sprintf("select * from %s where username = ? and valid_from < NOW() and expiration > NOW()", dab.tableName)

	rows, err := dab.db.Query(query, username)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while executing authentication query %s", err))
		return false, nil, err
	}

	defer rows.Close()
	for rows.Next() {
		apiUser := ApiUser{}
		err := rows.Scan(&apiUser.Username, &apiUser.Password, &apiUser.ValidFrom, &apiUser.Expiration, &apiUser.AccessLevel, &apiUser.TenantId)
		sharedutils.CheckError(err)

		if err := bcrypt.CompareHashAndPassword([]byte(apiUser.Password), []byte(password)); err != nil {
			return false, nil, nil
		} else {
			return true, dab.buildTokenInfo(ctx, &apiUser), nil
		}
	}

	return false, nil, nil
}

func (dab *DbAuthenticationBackend) buildTokenInfo(ctx context.Context, apiUser *ApiUser) *TokenInfo {
	adminRoles := strings.Split(apiUser.AccessLevel, ",")

	adminRolesMap := make(map[string]bool)

	for _, role := range adminRoles {
		// Trim it of any leading or suffix spaces
		role = strings.Trim(role, " ")
		adminRolesMap[role] = true
	}

	query := fmt.Sprintf("select * from tenant where id = ?")

	tenantid := apiUser.TenantId

	rows, err := dab.db.Query(query, tenantid)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while executing authentication query %s", err))
	}

	defer rows.Close()
	tenant := Tenant{}

	err = rows.Scan(&tenant.Id, &tenant.Name, &tenant.PortalDomainName, &tenant.DomainName)
	sharedutils.CheckError(err)

	return &TokenInfo{AdminRoles: adminRolesMap, Tenant: tenant}
}
