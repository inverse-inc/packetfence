package handlers

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/admin_api_audit_log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// EAB admin API. ACME's External Account Binding (RFC 8555 §7.3.4) is
// what lets PacketFence operators preauthorize a fleet of devices to
// enroll under an ACME-enabled profile: each device's MDM payload
// carries one (KeyID, HMACKey) pair we minted here, and any /new-account
// request without a matching JWS gets rejected.
//
// Endpoints (mounted at /api/v1/pki/profile/{id}/acme/eab):
//
//   GET  /                  list EAB keys for the profile
//   POST /                  mint a new EAB key — HMAC returned once
//   DELETE /{eab_id}        revoke an EAB key (idempotent)
//
// The HMAC is returned URL-safe base64 ONLY on creation; subsequent
// GETs return the row with HMAC blanked so admins can't lift a key
// from list output. If an admin lost the HMAC they must rotate.

// eabResponse is the JSON shape returned to admin clients. HMAC is
// only populated by POST (creation).
type eabResponse struct {
	ID             uint   `json:"id"`
	KeyID          string `json:"key_id"`
	HMAC           string `json:"hmac,omitempty"`
	Reference      string `json:"reference,omitempty"`
	BoundAccountID uint   `json:"bound_account_id,omitempty"`
	CreatedAt      string `json:"created_at"`
}

type eabCreatePayload struct {
	Reference string `json:"reference"`
}

func eabRowToResponse(r *models.AcmeExternalAccountKey, includeHMAC bool) eabResponse {
	out := eabResponse{
		ID:             r.ID,
		KeyID:          r.KeyID,
		Reference:      r.Reference,
		BoundAccountID: r.BoundAccountID,
		CreatedAt:      r.CreatedAt.UTC().Format("2006-01-02T15:04:05Z"),
	}
	if includeHMAC {
		out.HMAC = r.HMACKey
	}
	return out
}

// AcmeEABList serves GET /api/v1/pki/profile/{id}/acme/eab — paginated
// is overkill for a per-profile key set, so we return the lot. Keys
// are ordered newest-first so rotation candidates show at the top.
func AcmeEABList(pfpki *types.Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		profileID, ok := eabProfileID(w, r)
		if !ok {
			return
		}
		var rows []models.AcmeExternalAccountKey
		if err := pfpki.DB.Where("profile_id = ?", profileID).
			Order("created_at DESC").Find(&rows).Error; err != nil {
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
		out := make([]eabResponse, 0, len(rows))
		for i := range rows {
			out = append(out, eabRowToResponse(&rows[i], false))
		}
		w.Header().Set("Content-Type", "application/json; charset=UTF-8")
		_ = json.NewEncoder(w).Encode(map[string]any{"items": out})
	}
}

// AcmeEABCreate serves POST /api/v1/pki/profile/{id}/acme/eab. Body is
// {"reference": "..."} (optional human label). HMAC is returned once
// and never again.
//
// Key material: 64 random bytes URL-safe base64 — that's 86 chars of
// HMAC key, ~512 bits of entropy. The KeyID is 16 random bytes
// (URL-safe base64) for ~128 bits and short enough to embed in MDM
// payloads readably.
func AcmeEABCreate(pfpki *types.Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		profileID, ok := eabProfileID(w, r)
		if !ok {
			return
		}
		body, _ := io.ReadAll(r.Body)
		var payload eabCreatePayload
		_ = json.Unmarshal(body, &payload) // payload is fully optional

		kidBytes := make([]byte, 16)
		if _, err := rand.Read(kidBytes); err != nil {
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
		hmacBytes := make([]byte, 64)
		if _, err := rand.Read(hmacBytes); err != nil {
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
		row := models.AcmeExternalAccountKey{
			ProfileID: profileID,
			KeyID:     base64.RawURLEncoding.EncodeToString(kidBytes),
			HMACKey:   base64.RawURLEncoding.EncodeToString(hmacBytes),
			Reference: payload.Reference,
		}
		if err := pfpki.DB.Create(&row).Error; err != nil {
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}

		// Audit. Don't log the HMAC itself — only the KID is admin-safe.
		writeAdminAuditFromRequest(pfpki, r, "pfpki.AcmeEABCreate",
			strconv.FormatUint(uint64(row.ID), 10), http.StatusCreated,
			map[string]any{"profile_id": profileID, "key_id": row.KeyID})

		w.Header().Set("Content-Type", "application/json; charset=UTF-8")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(eabRowToResponse(&row, true))
	}
}

// AcmeEABDelete serves DELETE /api/v1/pki/profile/{id}/acme/eab/{eab_id}.
// Soft-delete via gorm so audit history stays correlatable; the EAB
// validator already filters DeletedAt.
//
// Idempotent: deleting a non-existent or already-revoked key returns
// 204 so an admin retrying after a network failure doesn't see 404.
func AcmeEABDelete(pfpki *types.Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		profileID, ok := eabProfileID(w, r)
		if !ok {
			return
		}
		vars := types.Params(r, "eab_id")
		eabID, err := strconv.ParseUint(vars["eab_id"], 10, 64)
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "bad eab_id")
			return
		}
		var row models.AcmeExternalAccountKey
		if err := pfpki.DB.Where("id = ? AND profile_id = ?", eabID, profileID).
			First(&row).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				// Idempotent.
				w.WriteHeader(http.StatusNoContent)
				return
			}
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if err := pfpki.DB.Delete(&row).Error; err != nil {
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeAdminAuditFromRequest(pfpki, r, "pfpki.AcmeEABDelete",
			strconv.FormatUint(eabID, 10), http.StatusNoContent,
			map[string]any{"profile_id": profileID, "key_id": row.KeyID})
		w.WriteHeader(http.StatusNoContent)
	}
}

// eabProfileID extracts the {id} URL param and confirms the profile
// exists. Returns (id, true) on success or writes a 4xx and returns
// (_, false) on failure.
func eabProfileID(w http.ResponseWriter, r *http.Request) (uint, bool) {
	vars := types.Params(r, "id")
	id, err := strconv.ParseUint(vars["id"], 10, 64)
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, "bad profile id")
		return 0, false
	}
	return uint(id), true
}

// writeJSONError emits the same shape the rest of pfpki uses for
// non-success answers so admin UI deserialization stays uniform.
func writeJSONError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(types.Errors{Status: status, Message: msg})
}

// AcmeEABMobileConfig serves
// GET /api/v1/pki/profile/{id}/acme/eab/{eab_id}/mobileconfig
//
// Returns a ready-to-import .mobileconfig payload containing a single
// com.apple.security.acme block, wired to:
//
//   - This installation's ACME directory URL for the profile.
//   - The (KeyID, HMACKey) pair of the named EAB row.
//
// The operator hands this file to their MDM tool (Jamf/Intune/etc.) as
// the certificate payload template for the device fleet. Per-device
// MDM systems typically substitute the device's UDID into the
// SubjectAltName field at deploy time; we leave that placeholder in
// the plist for the MDM template language to fill.
//
// Why we ship the plain mobileconfig rather than a signed one: signing
// would require the operator's own MDM CA, and Apple's MDM stack
// signs/encrypts the payload before delivery to the device. PacketFence
// is the template source, not the signer.
//
// Format reference: Apple's Configuration Profile Reference,
// CertificatePayload → ACME (com.apple.security.acme).
func AcmeEABMobileConfig(pfpki *types.Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		profileID, ok := eabProfileID(w, r)
		if !ok {
			return
		}
		vars := types.Params(r, "eab_id")
		eabID, err := strconv.ParseUint(vars["eab_id"], 10, 64)
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "bad eab_id")
			return
		}
		var prof models.Profile
		if err := pfpki.DB.First(&prof, profileID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				writeJSONError(w, http.StatusNotFound, "no such profile")
				return
			}
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
		var eab models.AcmeExternalAccountKey
		if err := pfpki.DB.Where("id = ? AND profile_id = ?", eabID, profileID).
			First(&eab).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				writeJSONError(w, http.StatusNotFound, "no such EAB key")
				return
			}
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}

		// Reconstruct the ACME directory URL the device will hit.
		// Falls back to /acme/{profile}/directory on this host header
		// — same logic the ACME handler uses via baseURL().
		directoryURL := acmeDirectoryURL(r, prof.Name)

		plist := buildACMEMobileConfig(prof.Name, directoryURL, eab.KeyID, eab.HMACKey)

		writeAdminAuditFromRequest(pfpki, r, "pfpki.AcmeEABMobileConfig",
			strconv.FormatUint(eabID, 10), http.StatusOK,
			map[string]any{"profile_id": profileID, "key_id": eab.KeyID})

		w.Header().Set("Content-Type", "application/x-apple-aspen-config")
		w.Header().Set("Content-Disposition",
			fmt.Sprintf(`attachment; filename="pfpki-acme-%s.mobileconfig"`, sanitizeFilename(prof.Name)))
		_, _ = w.Write([]byte(plist))
	}
}

// acmeDirectoryURL mirrors the URL pfpki/acme/directory.go::baseURL
// builds at request time. Reproduced here (instead of imported) because
// the admin handler is unauthenticated for ACME purposes and shouldn't
// drag in the ACME package's JWS internals.
func acmeDirectoryURL(r *http.Request, profileName string) string {
	scheme := "https"
	if r.Header.Get("X-Forwarded-Proto") != "" {
		scheme = r.Header.Get("X-Forwarded-Proto")
	} else if r.TLS == nil {
		scheme = "http"
	}
	host := r.Host
	if fwd := r.Header.Get("X-Forwarded-Host"); fwd != "" {
		host = fwd
	}
	return fmt.Sprintf("%s://%s/api/v1/pki/acme/%s/directory", scheme, host, profileName)
}

// buildACMEMobileConfig renders the Apple ACME payload plist. Kept as
// plain string formatting (no encoding/xml) because the structure is
// fully fixed and small; the variable bits are XML-escaped via the
// helper at the bottom.
//
// The payload requests an RSA-2048 cert per Apple's reference; that's
// what most enrollments use, and pfpki supports it. The HardwareBound
// field is true — Apple's ACME device-attest-01 requires the key be
// generated by the Secure Enclave and attested, which is the whole
// reason we built this flow.
//
// SubjectAltName: the placeholder %SerialNumber% is what the operator's
// MDM stack will substitute at deploy time. We can't fill it here
// because pfpki doesn't know the target device.
func buildACMEMobileConfig(profileName, directoryURL, keyID, hmacKey string) string {
	payloadUUID := strings.ToUpper(uuid.NewString())
	rootUUID := strings.ToUpper(uuid.NewString())
	return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key>
      <string>com.apple.security.acme</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>PayloadIdentifier</key>
      <string>com.packetfence.acme.` + xmlEscape(profileName) + `</string>
      <key>PayloadUUID</key>
      <string>` + payloadUUID + `</string>
      <key>PayloadDisplayName</key>
      <string>PacketFence ACME (` + xmlEscape(profileName) + `)</string>
      <key>DirectoryURL</key>
      <string>` + xmlEscape(directoryURL) + `</string>
      <key>ClientIdentifier</key>
      <string>` + xmlEscape(keyID) + `</string>
      <key>KeySize</key>
      <integer>2048</integer>
      <key>KeyType</key>
      <string>RSA</string>
      <key>HardwareBound</key>
      <true/>
      <key>Attest</key>
      <true/>
      <key>ExtendedKeyUsage</key>
      <array>
        <string>1.3.6.1.5.5.7.3.2</string>
      </array>
      <key>Subject</key>
      <array>
        <array>
          <array>
            <string>CN</string>
            <string>%HardwareUUID%</string>
          </array>
        </array>
      </array>
      <key>SubjectAltName</key>
      <dict>
        <key>ntPrincipalName</key>
        <string>%HardwareUUID%</string>
      </dict>
      <key>UsageFlags</key>
      <integer>1</integer>
      <key>ClientSecret</key>
      <string>` + xmlEscape(hmacKey) + `</string>
    </dict>
  </array>
  <key>PayloadDisplayName</key>
  <string>PacketFence ACME Enrollment</string>
  <key>PayloadIdentifier</key>
  <string>com.packetfence.acme.` + xmlEscape(profileName) + `.root</string>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string>` + rootUUID + `</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>
`
}

func xmlEscape(s string) string {
	r := strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;", "'", "&apos;")
	return r.Replace(s)
}

// sanitizeFilename keeps the downloaded filename free of separators
// so a profile named "lab/2026" doesn't break the Content-Disposition
// header parser on the client.
func sanitizeFilename(s string) string {
	r := strings.NewReplacer("/", "_", `\`, "_", `"`, "_", " ", "_")
	return r.Replace(s)
}

// writeAdminAuditFromRequest is the fire-and-forget admin audit insert
// for the EAB endpoints; mirrors makeAdminApiAuditLog but writes a
// JSON detail blob rather than the full request body (which would
// include HMAC material we don't want persisted).
func writeAdminAuditFromRequest(pfpki *types.Handler, req *http.Request, action, objectID string, status int, detail map[string]any) {
	blob, _ := json.Marshal(detail)
	row := &admin_api_audit_log.AdminApiAuditLog{
		UserName: req.Header.Get("X-PacketFence-Username"),
		Url:      req.URL.Path,
		Action:   action,
		ObjectId: objectID,
		Method:   req.Method,
		Request:  string(blob),
		Status:   int16(status),
	}
	_ = admin_api_audit_log.Add(pfpki.DB, row)
}
