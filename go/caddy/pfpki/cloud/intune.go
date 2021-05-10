package cloud

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"github.com/Azure/go-autorest/autorest/adal"
	"github.com/davecgh/go-spew/spew"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
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
	TransactionId                string `json:"transactionId"`
	CertificateRequest           []byte `json:"certificateRequest"`
	CertificateThumbprint        string `json:"certificateThumbprint"`
	CertificateSerialNumber      string `json:"certificateSerialNumber"`
	CertificateExpirationDateUtc string `json:"certificateExpirationDateUtc"`
	IssuingCertificateAuthority  string `json:"issuingCertificateAuthority"`
	HResult                      int64  `json:"hResult"`
	ErrorDescription             string `json:"errorDescription"`
	CallerInfo                   string `json:"callerInfo"`
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
const PROVIDER_NAME_AND_VERSION_NAME = "PacketFence 10.3"

const intuneAppId = "0000000a-0000-0000-c000-000000000000"
const intuneResourceUrl = "https://api.manage.microsoft.com/"
const graphApiVersion = "1.6"
const graphResourceUrl = "https://graph.windows.net/"

func NewIntuneCloud(ctx context.Context, name string) (Cloud, error) {

	Cloud := &Intune{}
	Cloud.CloudName = name
	Cloud.NewCloud(ctx, name)

	return Cloud, nil
}

func (cl *Intune) NewCloud(ctx context.Context, name string) {

	var cloud pfconfigdriver.Cloud
	pfconfigdriver.FetchDecodeSocket(ctx, &cloud)

	for cname, vi := range cloud.Element {
		if cname == name {
			cl.ClientID = vi.(map[string]interface{})["client_id"].(string)
			cl.TenantID = vi.(map[string]interface{})["tenant_id"].(string)
			cl.ClientSecret = vi.(map[string]interface{})["client_secret"].(string)
		}
	}

	oauthConfig, err := adal.NewOAuthConfig(activeDirectoryEndpoint, cl.TenantID)

	// Intune token

	spt, err := adal.NewServicePrincipalToken(*oauthConfig, cl.ClientID, cl.ClientSecret, intuneResourceUrl)

	err = spt.Refresh()

	var token adal.Token

	if err == nil {
		token = spt.Token()
		cl.AccessToken = "Bearer " + token.AccessToken
	}

	id, err := uuid.NewUUID()
	cl.TransactionID = id.String()

	spew.Dump(cl)

	spt, err = adal.NewServicePrincipalToken(*oauthConfig, cl.ClientID, cl.ClientSecret, graphResourceUrl)

	err = spt.Refresh()

	var Bearer string

	if err == nil {
		token = spt.Token()
		Bearer = "Bearer " + token.AccessToken
	}

	graphRequest := graphResourceUrl + cl.TenantID + "/servicePrincipalsByAppId/" + intuneAppId + "/serviceEndpoints?api-version=" + graphApiVersion

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{CipherSuites: []uint16{
			tls.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,
			tls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,
		},
			PreferServerCipherSuites: true,
			InsecureSkipVerify:       true,
			MinVersion:               tls.VersionTLS11,
			MaxVersion:               tls.VersionTLS11,
			Renegotiation:            tls.RenegotiateOnceAsClient,
		},
	}

	client := &http.Client{Transport: tr}
	cl.Client = client

	req, err := http.NewRequest("GET", graphRequest, nil)
	if err != nil {
		log.Print(err)
		os.Exit(1)
	}

	req.Header.Set("Authorization", Bearer)
	req.Header.Set("api-version", "1.0")
	req.Header.Set("client-request-id", id.String())
	resp, err := cl.Client.Do(req)

	var Data interface{}

	body, err := ioutil.ReadAll(resp.Body)

	json.Unmarshal(body, &Data)

	apiEndpoint := &APIEndPoint{}

	for k, v := range Data.(map[string]interface{}) {
		if k == "value" {
			for _, n := range v.([]interface{}) {
				for a, b := range n.(map[string]interface{}) {
					if a == "serviceName" {
						if b == VALIDATION_SERVICE_NAME {
							apiEndpoint.OdataType = n.(map[string]interface{})["odata.type"].(string)
							apiEndpoint.ObjectId = n.(map[string]interface{})["objectId"].(string)
							apiEndpoint.ResourceId = n.(map[string]interface{})["resourceId"].(string)
							apiEndpoint.ObjectType = n.(map[string]interface{})["objectType"].(string)
							// apiEndpoint.DeletionTimestamp = n.(map[string]interface{})["deletionTimestamp"].(interface{})
							apiEndpoint.Capability = n.(map[string]interface{})["capability"].(string)
							apiEndpoint.ServiceId = n.(map[string]interface{})["serviceId"].(string)
							apiEndpoint.ServiceName = n.(map[string]interface{})["serviceName"].(string)
							apiEndpoint.Uri = n.(map[string]interface{})["uri"].(string)
						}
					}
				}
			}
		}
	}
	cl.Endpoint = apiEndpoint
	spew.Dump(apiEndpoint)
}

func (cl *Intune) ValidateRequest(ctx context.Context, data []byte) error {

	request := &Request{}

	// Prepare the request
	request.Request.TransactionId = cl.TransactionID
	// Base 64 encoded PKCS10 packet
	request.Request.CertificateRequest = data
	request.Request.CallerInfo = PROVIDER_NAME_AND_VERSION_NAME

	slcB, _ := json.Marshal(request)
	fmt.Println(string(slcB))

	req, err := http.NewRequest("POST", cl.Endpoint.Uri+"/"+VALIDATION_URL, bytes.NewBuffer(slcB))
	if err != nil {
		log.Print(err)
		os.Exit(1)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("accept", "application/json")
	req.Header.Set("authorization", cl.AccessToken)
	req.Header.Set("api-version", "1.0")
	req.Header.Set("client-request-id", cl.TransactionID)
	req.Header.Set("api-version", serviceVersion)
	resp, err := cl.Client.Do(req)
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return errors.New("Unable to verify the scep request on intune")
	}
	return nil
}

func (cl *Intune) SuccessReply(ctx context.Context, cert *x509.Certificate, data []byte, message string) error {
	request := &Notification{}

	// Prepare the request
	request.Notification.TransactionId = cl.TransactionID
	// Base 64 encoded PKCS10 packet
	request.Notification.CertificateRequest = data
	request.Notification.CallerInfo = PROVIDER_NAME_AND_VERSION_NAME
	request.Notification.CertificateThumbprint = certutils.ThumbprintSHA1(cert)
	request.Notification.CertificateExpirationDateUtc = cert.NotAfter.String()
	request.Notification.CertificateSerialNumber = cert.Issuer.SerialNumber
	request.Notification.IssuingCertificateAuthority = cert.Issuer.CommonName

	slcB, _ := json.Marshal(request)
	fmt.Println(string(slcB))

	req, err := http.NewRequest("POST", cl.Endpoint.Uri+"/"+NOTIFY_SUCCESS_URL, bytes.NewBuffer(slcB))
	if err != nil {
		log.Print(err)
		os.Exit(1)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("accept", "application/json")
	req.Header.Set("authorization", cl.AccessToken)
	req.Header.Set("api-version", "1.0")
	req.Header.Set("client-request-id", cl.TransactionID)
	req.Header.Set("api-version", serviceVersion)
	resp, err := cl.Client.Do(req)
	defer resp.Body.Close()
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
	fmt.Println(string(slcB))

	req, err := http.NewRequest("POST", cl.Endpoint.Uri+"/"+NOTIFY_FAILURE_URL, bytes.NewBuffer(slcB))
	if err != nil {
		log.Print(err)
		os.Exit(1)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("accept", "application/json")
	req.Header.Set("authorization", cl.AccessToken)
	req.Header.Set("api-version", "1.0")
	req.Header.Set("client-request-id", cl.TransactionID)
	req.Header.Set("api-version", serviceVersion)
	resp, err := cl.Client.Do(req)
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return errors.New("Unable to verify the scep request on intune")
	}
	return nil
}
