package cloud

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"os"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/google/uuid"
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
	CloudName     string
	AccessToken   string
	TenantID      string
	ClientSecret  string
	ClientID      string
	Endpoint      *APIEndPoint
	TransactionID string
	Client        *http.Client
}

const activeDirectoryEndpoint = "https://login.microsoftonline.com/"

const serviceVersion = "2018-02-20"
const VALIDATION_SERVICE_NAME = "ScepRequestValidationFEService"
const VALIDATION_URL = "ScepActions/validateRequest"
const NOTIFY_SUCCESS_URL = "ScepActions/successNotification"
const NOTIFY_FAILURE_URL = "ScepActions/failureNotification"
const SERVICE_VERSION_PROP_NAME = VALIDATION_SERVICE_NAME + "Version"
const PROVIDER_NAME_AND_VERSION_NAME = "PacketFence"

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
			cl.ClientSecret = vi.(map[string]interface{})["client_secret"].(string)
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
		if k == "value" {
			for _, n := range v.([]interface{}) {
				for a, b := range n.(map[string]interface{}) {
					if a == "providerName" {
						if b == VALIDATION_SERVICE_NAME {
							apiEndpoint.Uri = n.(map[string]interface{})["uri"].(string)
						}
					}
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
