package acme

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/admin_api_audit_log"
	"gorm.io/gorm"
)

// auditACMEEvent writes a row into admin_api_audit_log for an
// operator-visible ACME state change. The audit log is the existing
// PacketFence pipeline for "who did what" — surfacing ACME activity
// there lets ops grep account creation, EAB key management, and cert
// revocations from one place instead of three.
//
// ACME callers aren't admins, so UserName is set to a synthetic
// "acme:<profile>/<account_key_id>" so log search still discriminates
// per-profile traffic. Request is a small JSON detail blob — keep it
// short; admin_api_audit_log.request is a TEXT column but we don't
// want to dump JWS payloads in there.
//
// Errors writing the audit row are logged but never propagated: a
// failed audit insert must not break the ACME flow itself.
func auditACMEEvent(ctx context.Context, db *gorm.DB, profileName, actor, action, objectID, method, url string, status int, detail any) {
	var requestBlob string
	if detail != nil {
		if b, err := json.Marshal(detail); err == nil {
			requestBlob = string(b)
		}
	}
	userName := "acme:" + profileName
	if actor != "" {
		userName = userName + "/" + actor
	}
	row := &admin_api_audit_log.AdminApiAuditLog{
		UserName: userName,
		Url:      url,
		Action:   action,
		ObjectId: objectID,
		Method:   method,
		Request:  requestBlob,
		Status:   int16(status),
	}
	if err := admin_api_audit_log.Add(db, row); err != nil {
		log.LoggerWContext(ctx).Warn("audit log insert failed for ACME event " + action + ": " + err.Error())
	}
}

// requestActor pulls a stable per-account identity from the JWS
// context so the audit log can attribute the event. Prefers the
// account's Location URL (the kid), falls back to the JWK thumbprint
// for /new-account where no kid exists yet.
func requestActor(jc *jwsContext) string {
	if jc == nil {
		return ""
	}
	if jc.Account != nil && jc.Account.KeyID != "" {
		return jc.Account.KeyID
	}
	if jc.JWK != nil {
		if t, err := jwsThumbprint(jc.JWK); err == nil {
			return t
		}
	}
	return ""
}

// requestURLForAudit returns the full URL we'd record on the audit row.
// Mirrors the JWS expectedRequestURL helper so the row's URL column
// matches the value the protocol used.
func requestURLForAudit(r *http.Request) string {
	return expectedRequestURL(r)
}
