// Package acme implements an RFC 8555 ACME (Automatic Certificate
// Management Environment) server bolted onto the existing pfpki CA /
// profile model. The motivating use case is Apple's managed-device
// enrollment flow, which uses ACME with the device-attest-01 challenge
// (RFC 9447) rather than SCEP.
//
// The package is intentionally light on third-party deps: go-jose for
// JWS validation and fxamacker/cbor for the Apple attestation object.
// Everything else (state machine, persistence, challenge validation,
// nonce store) is local code backed by the pfpki gorm models.
package acme

import (
	"encoding/json"
	"net/http"
)

// Problem is the RFC 7807 "Problem Details for HTTP APIs" shape ACME
// servers send back on errors (RFC 8555 §6.7). Each error has a stable
// URN under urn:ietf:params:acme:error: which clients dispatch on.
type Problem struct {
	Type        string         `json:"type"`
	Detail      string         `json:"detail,omitempty"`
	Status      int            `json:"status,omitempty"`
	Subproblems []Problem      `json:"subproblems,omitempty"`
	Identifier  map[string]any `json:"identifier,omitempty"`
}

// Stable ACME error URNs (subset — the rest get filled in as their
// handlers land). Keep them grouped here so a future handler doesn't
// have to invent a URN at the call site.
const (
	ErrAccountDoesNotExist     = "urn:ietf:params:acme:error:accountDoesNotExist"
	ErrAlreadyRevoked          = "urn:ietf:params:acme:error:alreadyRevoked"
	ErrBadCSR                  = "urn:ietf:params:acme:error:badCSR"
	ErrBadNonce                = "urn:ietf:params:acme:error:badNonce"
	ErrBadPublicKey            = "urn:ietf:params:acme:error:badPublicKey"
	ErrBadRevocationReason     = "urn:ietf:params:acme:error:badRevocationReason"
	ErrBadSignatureAlgorithm   = "urn:ietf:params:acme:error:badSignatureAlgorithm"
	ErrExternalAccountRequired = "urn:ietf:params:acme:error:externalAccountRequired"
	ErrInvalidContact          = "urn:ietf:params:acme:error:invalidContact"
	ErrMalformed               = "urn:ietf:params:acme:error:malformed"
	ErrOrderNotReady           = "urn:ietf:params:acme:error:orderNotReady"
	ErrRateLimited             = "urn:ietf:params:acme:error:rateLimited"
	ErrRejectedIdentifier      = "urn:ietf:params:acme:error:rejectedIdentifier"
	ErrServerInternal          = "urn:ietf:params:acme:error:serverInternal"
	ErrUnauthorized            = "urn:ietf:params:acme:error:unauthorized"
	ErrUnsupportedContact      = "urn:ietf:params:acme:error:unsupportedContact"
	ErrUnsupportedIdentifier   = "urn:ietf:params:acme:error:unsupportedIdentifier"
	ErrUserActionRequired      = "urn:ietf:params:acme:error:userActionRequired"
)

// WriteProblem emits an RFC 7807 application/problem+json response
// with the canonical ACME content type. Returning the encoder error
// is intentional — the caller logs it if it cares.
func WriteProblem(w http.ResponseWriter, status int, errType, detail string) error {
	w.Header().Set("Content-Type", "application/problem+json")
	w.WriteHeader(status)
	return json.NewEncoder(w).Encode(Problem{
		Type:   errType,
		Detail: detail,
		Status: status,
	})
}
