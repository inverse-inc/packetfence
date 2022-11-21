package pfk8s

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"

	"github.com/inverse-inc/go-utils/sharedutils"
)

type PodList struct {
	Items []struct {
		Status struct {
			PodIP             string `json:"podIP"`
			ContainerStatuses []struct {
				Ready bool `json:"ready"`
			} `json:"containerStatuses"`
		}
		Spec struct {
			Containers []struct {
				Ports []struct {
					ContainerPort int `json:"containerPort"`
				}
			}
		}
	}
}

type Client struct {
	Token      string
	Scheme     string
	Host       string
	Namespace  string
	HTTPClient *http.Client
}

func NewClient(host string, token string) *Client {
	return &Client{Host: host, Token: token, Namespace: "default"}
}

func NewClientFromEnv() *Client {
	host := sharedutils.EnvOrDefault("KUBERNETES_MASTER", "localhost")
	token := sharedutils.ReadFromFileOrStr(sharedutils.EnvOrDefault("KUBERNETES_TOKEN_PATH", "/var/run/secrets/kubernetes.io/serviceaccount/token"))
	namespace := sharedutils.ReadFromFileOrStr(sharedutils.EnvOrDefault("KUBERNETES_NAMESPACE_PATH", "/var/run/secrets/kubernetes.io/serviceaccount/namespace"))

	c := NewClient(string(host), string(token))
	c.Namespace = string(namespace)

	return c
}

func (c *Client) SetTLSConfigFromEnv() {
	caCerts := []byte(sharedutils.ReadFromFileOrStr(sharedutils.EnvOrDefault("KUBERNETES_CA_PATH", "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")))
	rootCAs, _ := x509.SystemCertPool()
	if rootCAs == nil {
		rootCAs = x509.NewCertPool()
	}

	if ok := rootCAs.AppendCertsFromPEM(caCerts); !ok {
		fmt.Println("No K8S CA cert appended, using system certs only")
	}

	config := &tls.Config{
		RootCAs: rootCAs,
	}
	tr := &http.Transport{TLSClientConfig: config}
	c.getHttpClient().Transport = tr
}

func (c *Client) getHttpClient() *http.Client {
	if c.HTTPClient == nil {
		c.HTTPClient = &http.Client{}
	}
	return c.HTTPClient
}

func (c *Client) newRequest(method, path string, body io.Reader) (*http.Request, error) {
	scheme := "https"
	if c.Scheme != "" {
		scheme = c.Scheme
	}

	req, err := http.NewRequest(method, fmt.Sprintf("%s://%s%s", scheme, c.Host, path), body)
	if err != nil {
		return nil, err
	}

	req.Header.Add("Authorization", "Bearer "+c.Token)

	return req, nil
}

func (c *Client) ListPods(appSelector string) (PodList, error) {
	req, err := c.newRequest("GET", "/api/v1/namespaces/"+c.Namespace+"/pods?labelSelector=app="+appSelector, nil)
	if err != nil {
		return PodList{}, err
	}

	res, err := c.getHttpClient().Do(req)
	if err != nil {
		return PodList{}, err
	}

	defer res.Body.Close()
	b, err := ioutil.ReadAll(res.Body)
	if err != nil {
		return PodList{}, err
	}

	if res.StatusCode != http.StatusOK {
		return PodList{}, errors.New(fmt.Sprintf("Got bad status code %d: %s", res.StatusCode, string(b)))
	}

	var pods PodList
	err = json.Unmarshal(b, &pods)

	if err != nil {
		return pods, err
	}

	return pods, nil
}
