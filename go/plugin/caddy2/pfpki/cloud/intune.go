package cloud

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/config/pfcrypt"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
)

// Info struct
type RequestInfo struct {
	TransactionId      string `json:"transactionId"`
	CertificateRequest []byte `json:"certificateRequest"`
	CallerInfo         string `json:"callerInfo"`
}

type Request struct {
	Request RequestInfo `json:"request"`
}

type Notification struct {
	Notification NotificationInfo `json:"notification"`
}

type NotificationInfo struct {
	TransactionId                string `json:"transactionId,omitempty"`
	CertificateRequest           []byte `json:"certificateRequest,omitempty"`
	CertificateThumbprint        string `json:"certificateThumbprint,omitempty"`
	CertificateSerialNumber      string `json:"certificateSerialNumber,omitempty"`
	CertificateExpirationDateUtc string `json:"certificateExpirationDateUtc,omitempty"`
	IssuingCertificateAuthority  string `json:"issuingCertificateAuthority,omitempty"`
	HResult                      int64  `json:"hResult,omitempty"`
	ErrorDescription             string `json:"errorDescription,omitempty"`
	CallerInfo                   string `json:"callerInfo,omitempty"`
}

type APIEndPoint struct {
	Capability        string      `json:"capability"`
	Uri               string      `json:"uri"`
	ObjectType        string      `json:"objectType"`
	ObjectId          string      `json:"objectId"`
	ServiceId         string      `json:"serviceId"`
	ServiceName       string      `json:"serviceName"`
	ResourceId        string      `json:"resourceId"`
	OdataType         string      `json:"odata.Type"`
	DeletionTimestamp interface{} `json:"deletionTimestamp"`
}

// Memory struct
type Intune struct {
	CloudName         string
	AccessToken       string
	TenantID          string
	ClientSecret      string
	ClientID          string
	Endpoint          *APIEndPoint
	RevocationEndpoint *APIEndPoint
	TransactionID     string
	Client            *http.Client
}

const activeDirectoryEndpoint = "https://login.microsoftonline.com/"

const serviceVersion = "2018-02-20"
const VALIDATION_SERVICE_NAME = "ScepRequestValidationFEService"
const VALIDATION_URL = "ScepActions/validateRequest"
const NOTIFY_SUCCESS_URL = "ScepActions/successNotification"
const NOTIFY_FAILURE_URL = "ScepActions/failureNotification"
const SERVICE_VERSION_PROP_NAME = VALIDATION_SERVICE_NAME + "Version"
const PROVIDER_NAME_AND_VERSION_NAME = "PacketFence"

// Revocation-feed constants. Names taken from Microsoft's reference
// IntuneRevocationClient.java (Intune-Resource-Access repo). These do
// NOT come from a public schema — if a future Intune release renames
// them, both the discovery match below and the URL paths here have to
// be updated in lockstep.
const REVOCATION_SERVICE_NAME = "CARevocationRequestsFEService"
const REVOCATION_DOWNLOAD_URL = "CARevocationRequests/downloadRevocationRequests"
const REVOCATION_UPLOAD_URL = "CARevocationRequests/uploadRevocationResults"
// Hard cap so a misbehaving tenant can't make one call run for hours;
// MS suggests batching, and the operator can call again to drain more.
const REVOCATION_MAX_PER_CALL = 500

const intuneAppId = "0000000a-0000-0000-c000-000000000000"

const intuneResourceUrl = "https://api.manage.microsoft.com/"

const msGraphApiVersion = "1.0"
const msGraphResourceUrl = "https://graph.microsoft.com/"

var ErrorCode = []string{
	"Unknown",
	"Success",
	"CertificateRequestDecodingFailed",
	"ChallengePasswordMissing",
	"ChallengeDeserializationError",
	"ChallengeDecryptionError",
	"ChallengeDecodingError",
	"ChallengeInvalidTimestamp",
	"ChallengeExpired",
	"SubjectNameMissing",
	"SubjectNameMismatch",
	"SubjectAltNameMissing",
	"SubjectAltNameMismatch",
	"KeyUsageMismatch",
	"KeyLengthMismatch",
	"EnhancedKeyUsageMissing",
	"EnhancedKeyUsageMismatch",
	"AadKeyIdentifierListMissing",
	"RegisteredKeyMismatch",
	"SigningCertThumbprintMismatch",
	"ScepProfileNoLongerTargetedToTheClient",
	"SignatureValidationFailed",
	"BadCertificateRequestIdInChallenge",
	"BadDeviceIdInChallenge",
	"BadUserIdInChallenge",
}

func NewIntuneCloud(ctx context.Context, name string) (Cloud, error) {

	Cloud := &Intune{}
	Cloud.CloudName = name
	err := Cloud.NewCloud(ctx, name)

	return Cloud, err
}

func (cl *Intune) NewCloud(ctx context.Context, name string) error {

	var cloud pfconfigdriver.Cloud
	pfconfigdriver.FetchDecodeSocket(ctx, &cloud)

	for cname, vi := range cloud.Element {
		if cname == name {
			cl.ClientID = vi.(map[string]interface{})["client_id"].(string)
			cl.TenantID = vi.(map[string]interface{})["tenant_id"].(string)
			s, err := pfcrypt.PfDecrypt(vi.(map[string]interface{})["client_secret"].(string))
			if err != nil {
				return err
			}

			cl.ClientSecret = string(s)
		}
	}

	cred, err := azidentity.NewClientSecretCredential(cl.TenantID, cl.ClientID, cl.ClientSecret, nil)
	if err != nil {
		log.Print(err)
		return err
	}
	// Fetch the token for Graph api
	tk, err := cred.GetToken(
		context.TODO(), policy.TokenRequestOptions{Scopes: []string{msGraphResourceUrl + ".default"}},
	)
	if err == nil {
		cl.AccessToken = "Bearer " + tk.Token
	} else {
		log.Print(err)
		return err
	}

	id, err := uuid.NewUUID()
	cl.TransactionID = id.String()

	graphRequest := msGraphResourceUrl + "v" + msGraphApiVersion + "/servicePrincipals/appId=" + intuneAppId + "/endpoints"

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{CipherSuites: []uint16{
			tls.TLS_RSA_WITH_AES_128_CBC_SHA,
			tls.TLS_RSA_WITH_AES_256_CBC_SHA,
			tls.TLS_RSA_WITH_AES_128_CBC_SHA256,
			tls.TLS_RSA_WITH_AES_128_GCM_SHA256,
			tls.TLS_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,
			tls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,
			tls.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,
			tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
			tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
		},
			PreferServerCipherSuites: true,
			InsecureSkipVerify:       true,
			MinVersion:               tls.VersionTLS12,
			MaxVersion:               tls.VersionTLS12,
			Renegotiation:            tls.RenegotiateOnceAsClient,
		},
	}

	client := &http.Client{Transport: tr}
	cl.Client = client

	req, err := http.NewRequest("GET", graphRequest, nil)
	if err != nil {
		log.Print(err)
		return err
	}

	req.Header.Set("Authorization", cl.AccessToken)
	req.Header.Set("api-version", msGraphApiVersion)
	req.Header.Set("client-request-id", cl.TransactionID)
	resp, err := cl.Client.Do(req)

	var Data interface{}

	body, err := io.ReadAll(resp.Body)

	json.Unmarshal(body, &Data)

	apiEndpoint := &APIEndPoint{}

	for k, v := range Data.(map[string]interface{}) {
		if k == "odata.error" {
			for m, n := range v.(map[string]interface{}) {
				if m == "message" {
					for a, b := range n.(map[string]interface{}) {
						if a == "value" {
							return errors.New(b.(string))
						}
					}
				}
			}
		}
		if k == "error" {
			for m, n := range v.(map[string]interface{}) {
				if m == "message" {
					return errors.New(n.(string))
				}
			}
		}
		if k == "value" {
			for _, n := range v.([]interface{}) {
				m, _ := n.(map[string]interface{})
				if m == nil {
					continue
				}
				name, _ := m["providerName"].(string)
				uri, _ := m["uri"].(string)
				switch name {
				case VALIDATION_SERVICE_NAME:
					apiEndpoint.Uri = uri
				case REVOCATION_SERVICE_NAME:
					cl.RevocationEndpoint = &APIEndPoint{Uri: uri, ServiceName: name}
				}
			}
		}
	}

	// Fetch the token for intune api
	tk, err = cred.GetToken(
		context.TODO(), policy.TokenRequestOptions{Scopes: []string{intuneResourceUrl + "/.default"}},
	)

	if err == nil {
		cl.AccessToken = "Bearer " + tk.Token
	} else {
		log.Print(err)
		return err
	}

	cl.Endpoint = apiEndpoint
	return nil
}

func (cl *Intune) ValidateRequest(ctx context.Context, data []byte) error {

	request := &Request{}

	// Prepare the request
	request.Request.TransactionId = cl.TransactionID
	// Base 64 encoded PKCS10 packet
	request.Request.CertificateRequest = data
	request.Request.CallerInfo = PROVIDER_NAME_AND_VERSION_NAME

	slcB, _ := json.Marshal(request)

	req, err := http.NewRequest("POST", cl.Endpoint.Uri+"/"+VALIDATION_URL, bytes.NewBuffer(slcB))
	if err != nil {
		log.Print(err)
		os.Exit(1)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("accept", "application/json")
	req.Header.Set("authorization", cl.AccessToken)
	req.Header.Set("api-version", serviceVersion)
	req.Header.Set("client-request-id", cl.TransactionID)
	req.Header.Set("useragent", PROVIDER_NAME_AND_VERSION_NAME)
	resp, err := cl.Client.Do(req)
	if err != nil {
		return err
	}

	var Data interface{}

	body, err := io.ReadAll(resp.Body)

	json.Unmarshal(body, &Data)

	for k, v := range Data.(map[string]interface{}) {
		if k == "code" {
			if contains(ErrorCode, v.(string)) {
				if v.(string) == "Success" {
					return nil
				} else {
					return errors.New("Exception from Intune API: " + v.(string))
				}
			} else {
				return errors.New("Unknown return code from Intune API")
			}
		}
	}

	defer resp.Body.Close()
	return errors.New("Unable to verify the scep request on intune")
}

func (cl *Intune) SuccessReply(ctx context.Context, cert *x509.Certificate, data []byte, message string) error {
	request := &Notification{}

	// Prepare the request
	request.Notification.TransactionId = cl.TransactionID
	// Base 64 encoded PKCS10 packet
	request.Notification.CertificateRequest = data
	request.Notification.CallerInfo = PROVIDER_NAME_AND_VERSION_NAME
	request.Notification.CertificateThumbprint = certutils.ThumbprintSHA1(cert)
	request.Notification.CertificateExpirationDateUtc = cert.NotAfter.Format("2006-01-02T15:04:05-0700")
	request.Notification.CertificateSerialNumber = cert.SerialNumber.String()
	request.Notification.IssuingCertificateAuthority = cert.Issuer.CommonName

	slcB, _ := json.Marshal(request)

	req, err := http.NewRequest("POST", cl.Endpoint.Uri+"/"+NOTIFY_SUCCESS_URL, bytes.NewBuffer(slcB))
	if err != nil {
		log.Print(err)
		os.Exit(1)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("accept", "application/json")
	req.Header.Set("authorization", cl.AccessToken)
	req.Header.Set("api-version", msGraphApiVersion)
	req.Header.Set("client-request-id", cl.TransactionID)
	req.Header.Set("api-version", serviceVersion)
	resp, err := cl.Client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	_, err = io.ReadAll(resp.Body)

	if resp.StatusCode != 200 {
		return errors.New("Unable to verify the scep request on intune")
	}
	return nil
}

func (cl *Intune) FailureReply(ctx context.Context, cert *x509.Certificate, data []byte, message string) error {
	request := &Notification{}

	// Prepare the request
	request.Notification.TransactionId = cl.TransactionID
	// Base 64 encoded PKCS10 packet
	request.Notification.CertificateRequest = data
	request.Notification.CallerInfo = PROVIDER_NAME_AND_VERSION_NAME
	request.Notification.HResult = 1234
	request.Notification.ErrorDescription = message

	slcB, _ := json.Marshal(request)

	req, err := http.NewRequest("POST", cl.Endpoint.Uri+"/"+NOTIFY_FAILURE_URL, bytes.NewBuffer(slcB))
	if err != nil {
		log.Print(err)
		os.Exit(1)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("accept", "application/json")
	req.Header.Set("authorization", cl.AccessToken)
	req.Header.Set("api-version", msGraphApiVersion)
	req.Header.Set("client-request-id", cl.TransactionID)
	req.Header.Set("api-version", serviceVersion)
	resp, err := cl.Client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	_, err = io.ReadAll(resp.Body)

	if resp.StatusCode != 200 {
		return errors.New("Unable to verify the scep request on intune")
	}
	return nil
}

// contains checks if a string is present in a slice
func contains(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}

	return false
}

// --- Revocation feed (RevocationProcessor) ---
//
// JSON shapes follow Microsoft's IntuneRevocationClient.java reference
// (microsoft/Intune-Resource-Access on GitHub). They are NOT covered by
// a public schema, so this file is the integration's source of truth
// against that reference — any future Intune-side rename has to be
// mirrored here in one place.

type revocationDownloadRequest struct {
	MaxRequests                int    `json:"maxRequests"`
	CertificateProviderName    string `json:"certificateProviderName"`
	IssuerName                 string `json:"issuerName"`
	TransactionId              string `json:"transactionId"`
	CallerInfo                 string `json:"callerInfo"`
}

type revocationDownloadResponse struct {
	Value []revocationItem `json:"value"`
}

type revocationItem struct {
	RequestId            string `json:"requestContext"`
	SerialNumber         string `json:"serialNumber"`
	IssuerName           string `json:"issuerName"`
	CallerInfo           string `json:"callerInfo"`
	CertificateThumbprint string `json:"certificateThumbprint"`
	// Reason maps to RFC 5280 CRLReason; we forward it as-is to the
	// pfpki revoke path.
	Reason int `json:"revocationRequestReason"`
}

type revocationUploadRequest struct {
	TransactionId      string                  `json:"transactionId"`
	CertificateProviderName string             `json:"certificateProviderName"`
	IssuerName         string                  `json:"issuerName"`
	CallerInfo         string                  `json:"callerInfo"`
	Results            []revocationUploadResult `json:"results"`
}

type revocationUploadResult struct {
	RequestId        string `json:"requestContext"`
	Succeeded        bool   `json:"succeeded"`
	ErrorDescription string `json:"errorDescription,omitempty"`
}

// ProcessRevocations implements cloud.RevocationProcessor against Intune.
// caName is the issuing CA's Common Name; Intune matches revocation
// requests by issuer DN, but its API takes the CN. The caller invokes
// `revoke` for each downloaded entry; we collect the outcomes and POST
// them back so Intune stops re-publishing the same requests.
func (cl *Intune) ProcessRevocations(ctx context.Context, caName string, revoke RevokeFunc) (int, error) {
	if cl.RevocationEndpoint == nil || cl.RevocationEndpoint.Uri == "" {
		// Discovery didn't return a CARevocationRequestsFEService entry
		// for this tenant — either the tenant has no SCEP CA configured
		// in Intune or the service name has been renamed upstream.
		return 0, errors.New("intune: revocation endpoint not discovered (CARevocationRequestsFEService)")
	}

	dlReq := revocationDownloadRequest{
		MaxRequests:             REVOCATION_MAX_PER_CALL,
		CertificateProviderName: PROVIDER_NAME_AND_VERSION_NAME,
		IssuerName:              caName,
		TransactionId:           cl.TransactionID,
		CallerInfo:              PROVIDER_NAME_AND_VERSION_NAME,
	}
	dlBody, err := json.Marshal(dlReq)
	if err != nil {
		return 0, err
	}

	items, err := cl.postJSON(ctx, cl.RevocationEndpoint.Uri+"/"+REVOCATION_DOWNLOAD_URL, dlBody)
	if err != nil {
		return 0, err
	}

	var resp revocationDownloadResponse
	if err := json.Unmarshal(items, &resp); err != nil {
		return 0, fmt.Errorf("intune: parse download response: %w", err)
	}
	if len(resp.Value) == 0 {
		return 0, nil
	}

	results := make([]revocationUploadResult, 0, len(resp.Value))
	for _, it := range resp.Value {
		out := revoke(ctx, RevocationRequest{
			RequestID:    it.RequestId,
			SerialNumber: it.SerialNumber,
			Thumbprint:   it.CertificateThumbprint,
			Reason:       it.Reason,
			IssuerName:   it.IssuerName,
		})
		results = append(results, revocationUploadResult{
			RequestId:        out.RequestID,
			Succeeded:        out.Succeeded,
			ErrorDescription: out.ErrorDescription,
		})
	}

	ackBody, err := json.Marshal(revocationUploadRequest{
		TransactionId:           cl.TransactionID,
		CertificateProviderName: PROVIDER_NAME_AND_VERSION_NAME,
		IssuerName:              caName,
		CallerInfo:              PROVIDER_NAME_AND_VERSION_NAME,
		Results:                 results,
	})
	if err != nil {
		return len(results), err
	}
	if _, err := cl.postJSON(ctx, cl.RevocationEndpoint.Uri+"/"+REVOCATION_UPLOAD_URL, ackBody); err != nil {
		// Failed to acknowledge; Intune will re-send next time, which
		// is acceptable as long as the caller's revoke step was
		// idempotent. Return the count so the caller still knows
		// progress was made locally.
		return len(results), fmt.Errorf("intune: ack failed: %w", err)
	}
	return len(results), nil
}

// postJSON is the shared "auth + headers + read body" wrapper that the
// two revocation calls use. Returns the response body on 2xx.
func (cl *Intune) postJSON(ctx context.Context, url string, body []byte) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("accept", "application/json")
	req.Header.Set("authorization", cl.AccessToken)
	req.Header.Set("api-version", serviceVersion)
	req.Header.Set("client-request-id", cl.TransactionID)
	req.Header.Set("useragent", PROVIDER_NAME_AND_VERSION_NAME)
	resp, err := cl.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode/100 != 2 {
		return nil, fmt.Errorf("intune: %s -> %d: %s", url, resp.StatusCode, string(raw))
	}
	return raw, nil
}
