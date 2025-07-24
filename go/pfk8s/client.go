package pfk8s

import (
	"bytes"
	"cmp"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
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
	BaseURI    string
	Namespace  string
	HTTPClient *http.Client
}

func IsRunningInK8S() bool {
	return os.Getenv("K8S_MASTER_TOKEN") != ""
}

func NewAdminClientFromEnv() *Client {
	if !IsRunningInK8S() {
		return nil
	}

	baseURI := sharedutils.EnvOrDefault("K8S_MASTER_URI", "http://localhost")
	token := sharedutils.ReadFromFileOrStr(sharedutils.EnvOrDefault("K8S_ADMIN_TOKEN_PATH", "/var/run/secrets/kubernetes.io/serviceaccount/token"))
	namespace := sharedutils.ReadFromFileOrStr(sharedutils.EnvOrDefault("KUBERNETES_NAMESPACE_PATH", "/var/run/secrets/kubernetes.io/serviceaccount/namespace"))
	c := NewClient(baseURI, token, namespace)
	c.SetTLSConfigFromEnv()

	return c
}

func NewClient(baseURI string, token string, namespace string) *Client {
	return &Client{BaseURI: baseURI, Token: token, Namespace: cmp.Or(namespace, "default")}
}

func NewClientFromEnv() *Client {
	baseURI := sharedutils.EnvOrDefault("K8S_MASTER_URI", "http://localhost")
	token := sharedutils.EnvOrDefault("K8S_MASTER_TOKEN", "")
	namespace := sharedutils.ReadFromFileOrStr(sharedutils.EnvOrDefault("KUBERNETES_NAMESPACE_PATH", "/var/run/secrets/kubernetes.io/serviceaccount/namespace"))

	c := NewClient(baseURI, token, namespace)
	c.SetTLSConfigFromEnv()

	return c
}

func (c *Client) SetTLSConfigFromEnv() {
	c.SetTLSConfigFromFile(sharedutils.EnvOrDefault("K8S_MASTER_CA_FILE", "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"))
}

func (c *Client) SetTLSConfigFromFile(path string) {
	caCerts := []byte(sharedutils.ReadFromFileOrStr(path))
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
	req, err := http.NewRequest(method, fmt.Sprintf("%s%s", c.BaseURI, path), body)
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
	b, err := io.ReadAll(res.Body)
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

func (c *Client) PatchPorts(p []PatchPorts) error {
	data, err := json.Marshal(p)
	if err != nil {
		return fmt.Errorf("PatchPorts, failed to encode to JSON: %w", err)
	}

	req, err := c.newRequest("PATCH", "/api/v1/namespaces/"+c.Namespace+"/services/pfconnector", bytes.NewBuffer(data))
	if err != nil {
		return fmt.Errorf("PatchPorts, failed to create the request: %w", err)
	}

	req.Header.Add("Content-Type", "application/json-patch+json")
	resp, err := c.getHttpClient().Do(req)
	if err != nil {
		return fmt.Errorf("PatchPorts, failed request: %w", err)
	}

	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("PatchPorts, failed to read the body: %w", err)
	}

	if resp.StatusCode != 200 {
		return fmt.Errorf("PatchPorts, request error returned: %d %s", resp.StatusCode, string(body))
	}
	_ = body

	return nil
}

func (c *Client) GetService(serviceName string) (Service, error) {
	service := Service{}
	req, err := c.newRequest("GET", "/api/v1/namespaces/"+c.Namespace+"/services/"+serviceName, nil)
	if err != nil {
		return service, fmt.Errorf("GetService, failed to create the request: %w", err)
	}

	resp, err := c.getHttpClient().Do(req)
	if err != nil {
		return service, fmt.Errorf("GetService, failed request: %w", err)
	}

	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return service, fmt.Errorf("GetService, failed to read the body: %w", err)
	}

	if resp.StatusCode != 200 {
		return service, fmt.Errorf("GetService, request error returned: %d %s", resp.StatusCode, string(body))
	}

	err = json.Unmarshal(body, &service)

	if err != nil {
		return service, fmt.Errorf("GetService, failed to decode JSON: %w", err)
	}

	_ = body

	return service, nil
}

func (c *Client) UnifiedAPICallDeployment(ctx context.Context, useTLS bool, appSelector, method, path string, createResponseStructPtr func(serverId string) interface{}) map[string]error {
	errs := map[string]error{}

	pods, err := c.ListPods(appSelector)
	if err != nil {
		errs["ALL"] = err
		return errs
	}
	for _, pod := range pods.Items {
		if pod.Status.ContainerStatuses[0].Ready {
			client := unifiedapiclient.NewFromConfig(ctx)
			client.Host = pod.Status.PodIP
			client.Port = strconv.Itoa(pod.Spec.Containers[0].Ports[0].ContainerPort)
			client.Proto = "http"
			if useTLS {
				client.Proto = "https"
			}
			resp := createResponseStructPtr(client.Host)
			err := client.Call(ctx, method, path, resp)
			if err != nil {
				errs[client.Host] = err
			}
		}
	}
	return errs
}
