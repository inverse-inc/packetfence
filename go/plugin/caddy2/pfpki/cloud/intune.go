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
	CloudName          string
	AccessToken        string
	TenantID           string
	ClientSecret       string
	ClientID           string
	Endpoint           *APIEndPoint
	RevocationEndpoint *APIEndPoint
	TransactionID      string
	Client             *http.Client
}

const activeDirectoryEndpoint = "https://login.microsoftonline.com/"

const serviceVersion = "2018-02-20"
const VALIDATION_SERVICE_NAME = "ScepRequestValidationFEService"
const VALIDATION_URL = "ScepActions/validateRequest"
const NOTIFY_SUCCESS_URL = "ScepActions/successNotification"
const NOTIFY_FAILURE_URL = "ScepActions/failureNotification"
const SERVICE_VERSION_PROP_NAME = VALIDATION_SERVICE_NAME + "Version"
const PROVIDER_NAME_AND_VERSION_NAME = "PacketFence"

// Revocation-feed constants, from Microsoft's reference
// IntuneRevocationClient.java (microsoft/Intune-Resource-Access,
// src/CsrValidation/java). The connector service is discovered from
// the same Graph endpoint list as the SCEP validation service; both
// revocation calls are POSTs under CertificateAuthorityRequests/ and
// use their own api-version, not the SCEP validation one.
const REVOCATION_SERVICE_NAME = "PkiConnectorFEService"
const REVOCATION_DOWNLOAD_URL = "CertificateAuthorityRequests/downloadRevocationRequests"
const REVOCATION_UPLOAD_URL = "CertificateAuthorityRequests/uploadRevocationResults"
const REVOCATION_API_VERSION = "5019-05-05"

// REVOCATION_MAX_PER_CALL is the batch size per download. The
// reference client caps it at 500; Microsoft's API documentation
// recommends an upper bound of 100. Intune enforces a 60-minute
// cool-down after every download call (the queue returns nothing
// until it elapses), so a bigger batch does not drain faster — the
// next call an hour later does.
const REVOCATION_MAX_PER_CALL = 100

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
// Wire format per IntuneRevocationClient.java and
// carequest/CARevocationRequest.java / CARevocationResult.java:
//
//	POST <PkiConnectorFEService>/CertificateAuthorityRequests/downloadRevocationRequests
//	  -> {"downloadParameters":{"maxRequests":N,"issuerName":"<CN>"|null}}
//	  <- {"value":[{"requestContext":…,"serialNumber":…,"issuerName":…,"caConfiguration":…}]}
//	POST <PkiConnectorFEService>/CertificateAuthorityRequests/uploadRevocationResults
//	  -> {"results":[{"requestContext":…,"succeeded":bool,"errorCode":"0"|"4004"|…,"errorMessage":…}]}
//	  <- {"value":true}
//
// Intune identifies a certificate by what SuccessReply reported when
// it was issued: the decimal serial (cert.SerialNumber.String()) and
// the issuer CN, so the issuerName filter is the CA's CN.
//
// Microsoft's API page warns that this OData endpoint "will be removed
// in an upcoming API update" and that callers should go through their
// library instead. There is no Go library, so this is a port of the
// Java one; when Microsoft moves the endpoint, the constants above and
// the two request/response shapes below are the only things to update.

type revocationDownloadRequest struct {
	DownloadParameters revocationDownloadParameters `json:"downloadParameters"`
}

type revocationDownloadParameters struct {
	MaxRequests int     `json:"maxRequests"`
	IssuerName  *string `json:"issuerName"` // JSON null = every issuer
}

type revocationDownloadResponse struct {
	Value []revocationItem `json:"value"`
}

type revocationItem struct {
	RequestContext  string `json:"requestContext"`
	SerialNumber    string `json:"serialNumber"`
	IssuerName      string `json:"issuerName"`
	CAConfiguration string `json:"caConfiguration"`
}

type revocationUploadRequest struct {
	Results []revocationUploadResult `json:"results"`
}

type revocationUploadResult struct {
	RequestContext string `json:"requestContext"`
	Succeeded      bool   `json:"succeeded"`
	ErrorCode      string `json:"errorCode"`
	ErrorMessage   string `json:"errorMessage,omitempty"`
}

type revocationUploadResponse struct {
	Value json.RawMessage `json:"value"`
}

// ProcessRevocations implements cloud.RevocationProcessor against Intune.
// caName is the issuing CA's Common Name, the issuerName Intune stored
// for our certificates. The caller's revoke runs once per downloaded
// item; the outcomes are uploaded in one batch and Intune must answer
// {"value":true}, otherwise it will re-send the same items next time.
func (cl *Intune) ProcessRevocations(ctx context.Context, caName string, revoke RevokeFunc) (int, error) {
	if cl.RevocationEndpoint == nil || cl.RevocationEndpoint.Uri == "" {
		// Discovery did not return a PkiConnectorFEService entry for
		// this tenant, or the service has been renamed upstream.
		return 0, errors.New("intune: revocation endpoint not discovered (" + REVOCATION_SERVICE_NAME + ")")
	}

	params := revocationDownloadParameters{MaxRequests: REVOCATION_MAX_PER_CALL}
	if caName != "" {
		params.IssuerName = &caName
	}
	dlBody, err := json.Marshal(revocationDownloadRequest{DownloadParameters: params})
	if err != nil {
		return 0, err
	}
	raw, err := cl.postJSON(ctx, cl.RevocationEndpoint.Uri+"/"+REVOCATION_DOWNLOAD_URL, REVOCATION_API_VERSION, dlBody)
	if err != nil {
		return 0, err
	}
	var resp revocationDownloadResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		return 0, fmt.Errorf("intune: parse download response: %w", err)
	}
	if len(resp.Value) == 0 {
		return 0, nil
	}

	results := make([]revocationUploadResult, 0, len(resp.Value))
	for _, it := range resp.Value {
		if it.RequestContext == "" {
			// Nothing to acknowledge against; Intune will re-send it.
			continue
		}
		out := revoke(ctx, RevocationRequest{
			RequestID:       it.RequestContext,
			SerialNumber:    it.SerialNumber,
			IssuerName:      it.IssuerName,
			CAConfiguration: it.CAConfiguration,
		})
		// Intune rejects a success with a non-None code and a failure
		// with the None code; normalise so a sloppy callback can't make
		// the whole batch bounce.
		code := out.ErrorCode
		switch {
		case out.Succeeded:
			code = CARequestErrorNone
		case code == "" || code == CARequestErrorNone:
			code = CARequestErrorRetryable
		}
		results = append(results, revocationUploadResult{
			RequestContext: it.RequestContext,
			Succeeded:      out.Succeeded,
			ErrorCode:      code,
			ErrorMessage:   out.ErrorMessage,
		})
	}
	if len(results) == 0 {
		return 0, nil
	}

	ackBody, err := json.Marshal(revocationUploadRequest{Results: results})
	if err != nil {
		return len(results), err
	}
	raw, err = cl.postJSON(ctx, cl.RevocationEndpoint.Uri+"/"+REVOCATION_UPLOAD_URL, REVOCATION_API_VERSION, ackBody)
	if err != nil {
		// Not acknowledged; Intune re-sends next time. The caller's
		// revoke is idempotent so that is safe. Return the count so
		// the caller still knows local progress was made.
		return len(results), fmt.Errorf("intune: ack failed: %w", err)
	}
	var ack revocationUploadResponse
	if err := json.Unmarshal(raw, &ack); err != nil || string(ack.Value) != "true" {
		return len(results), fmt.Errorf("intune: upload of revocation results not accepted: %s", string(raw))
	}
	return len(results), nil
}

// postJSON is the shared "auth + headers + read body" wrapper that the
// two revocation calls use; the headers mirror IntuneClient.PostRequest
// in the reference client. Returns the response body on 2xx.
func (cl *Intune) postJSON(ctx context.Context, url, apiVersion string, body []byte) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("accept", "application/json")
	req.Header.Set("Authorization", cl.AccessToken)
	req.Header.Set("api-version", apiVersion)
	req.Header.Set("client-request-id", cl.TransactionID)
	req.Header.Set("UserAgent", PROVIDER_NAME_AND_VERSION_NAME)
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
