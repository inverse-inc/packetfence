package ntlm

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"io/ioutil"
	"net/http"
	"time"
)

func GetDomainConfig(ctx context.Context) (pfconfigdriver.Domain, error) {
	var domain pfconfigdriver.Domain
	err := pfconfigdriver.FetchDecodeSocket(ctx, &domain)
	if err != nil {
		return domain, nil
	}
	return domain, err
}

func CheckMachineAccountPassword(ctx context.Context, backendPort string) (bool, error) {
	url := "http://containers-gateway.internal:" + backendPort + "/ntlm/connect"

	client := &http.Client{
		Timeout: 2 * time.Second,
	}
	response, err := client.Get(url)
	if err != nil {
		return false, err
	}

	defer response.Body.Close()
	statusCode := response.StatusCode
	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return false, err
	}
	if statusCode != http.StatusOK {
		return false, errors.New(fmt.Sprintf("NTLM auth api returned with HTTP code: %d, %s", statusCode, string(body)))
	}
	return true, nil
}

func CheckMachineAccountWithGivenPassword(ctx context.Context, backendPort string, password string) (bool, error) {
	url := "http://containers-gateway.internal:" + backendPort + "/ntlm/connect"

	client := &http.Client{
		Timeout: 2 * time.Second,
	}

	jsonData := map[string]string{
		"password": password,
	}
	jsonBytes, _ := json.Marshal(jsonData)
	buffer := bytes.NewBuffer(jsonBytes)

	response, err := client.Post(url, "application/json", buffer)
	if err != nil {
		return false, err
	}

	defer response.Body.Close()
	statusCode := response.StatusCode
	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return false, err
	}
	if statusCode != http.StatusOK {
		return false, errors.New(fmt.Sprintf("NTLM auth api returned with HTTP code: %d, %s", statusCode, string(body)))
	}
	return true, nil
}

func ReportMSEvent(ctx context.Context, backendPort string, jsonData any) error {
	url := "http://containers-gateway.internal:" + backendPort + "/event/report"

	client := &http.Client{
		Timeout: 2 * time.Second,
	}

	jsonBytes, _ := json.Marshal(jsonData)
	buffer := bytes.NewBuffer(jsonBytes)

	response, err := client.Post(url, "application/json", buffer)
	if err != nil {
		return err
	}

	defer response.Body.Close()
	statusCode := response.StatusCode
	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return err
	}
	if statusCode == http.StatusOK || statusCode == http.StatusAccepted {
		return nil
	}
	return errors.New(fmt.Sprintf("NTLM event report API replied with HTTP code: %d, %s", statusCode, string(body)))
}
