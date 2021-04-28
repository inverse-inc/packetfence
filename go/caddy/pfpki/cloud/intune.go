package cloud

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"github.com/Azure/go-autorest/autorest/adal"
	"github.com/davecgh/go-spew/spew"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// Info struct
type RequestInfo struct {
	TransactionId      string `json:"transactionId"`
	CertificateRequest string `json:"certificateRequest"`
	CallerInfo         string `json:"callerInfo"`
}

type Request struct {
	Request RequestInfo `json:"request"`
}

type Notification struct {
	Notification NotificationInfo `json:"request"`
}

type NotificationInfo struct {
	TransactionId      string `json:"transactionId"`
	CertificateRequest string `json:"certificateRequest"`
	HResultstring      string `json:"hResult"`
	ErrorDescription   string `json:"errorDescription"`
	CallerInfo         string `json:"callerInfo"`
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
	CloudName    string
	AccessToken  string
	TenantID     string
	ClientSecret string
	ClientID     string
	Endpoint     *APIEndPoint
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

	for _, vi := range cloud.Element {
		for key, val := range vi.(map[string]interface{}) {
			if key == name {
				cl.ClientID = val.(map[string]interface{})["ClientID"].(string)
				cl.TenantID = val.(map[string]interface{})["TenantID"].(string)
				cl.ClientSecret = val.(map[string]interface{})["ClientSecret"].(string)
			}
		}
	}

	oauthConfig, err := adal.NewOAuthConfig(activeDirectoryEndpoint, cl.TenantID)

	spt, err := adal.NewServicePrincipalToken(*oauthConfig, cl.ClientID, cl.ClientSecret, graphResourceUrl)

	err = spt.Refresh()

	var token adal.Token
	if err == nil {
		token = spt.Token()
		cl.AccessToken = token.AccessToken
	}

	var bearer = "Bearer " + cl.AccessToken

	id, err := uuid.NewUUID()
	request := &Request{}

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
		},
	}

	client := &http.Client{Transport: tr}

	req, err := http.NewRequest("GET", graphRequest, nil)
	if err != nil {
		log.Print(err)
		os.Exit(1)
	}

	req.Header.Set("Authorization", bearer)
	req.Header.Set("api-version", "1.0")
	req.Header.Set("client-request-id", id.String())
	resp, err := client.Do(req)

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

	// Prepare the request
	request.Request.TransactionId = id.String()
	// Base 64 encoded PKCS10 packet
	request.Request.CertificateRequest = "aabbccddeeff"
	request.Request.CallerInfo = "bob"

	slcB, _ := json.Marshal(request)
	fmt.Println(string(slcB))

	if err != nil {
	}

	// client := &http.Client{Transport: tr}

	// req, err := http.NewRequest("POST", ressource, nil)
	// if err != nil {
	//  log.Print(err)
	//  os.Exit(1)
	// }
	// req.Header.Set("accept", "application/json")
	// req.Header.Set("authorization", bearer)
	// req.Header.Set("api-version", "1.0")
	// req.Header.Set("client-request-id", id.String())
	// _, err = client.Do(req)

	// spew.Dump(err)
	// // spew.Dump(resp)

}
