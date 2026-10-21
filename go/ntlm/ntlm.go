package ntlm

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func GetDomainConfig(ctx context.Context) (pfconfigdriver.ResourceDomains, error) {
	var domain pfconfigdriver.ResourceDomains
	err := pfconfigdriver.FetchDecodeSocket(ctx, &domain)
	if err != nil {
		return domain, err
	}
	return domain, nil
}

func CheckMachineAccountPassword(ctx context.Context, backendHostPort string) (bool, error) {
	url := "http://" + backendHostPort + "/ntlm/connect"

	client := &http.Client{
		Timeout: 16 * time.Second,
	}
	response, err := client.Get(url)
	if err != nil {
		return false, err
	}

	defer response.Body.Close()
	statusCode := response.StatusCode
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return false, err
	}
	if statusCode != http.StatusOK {
		return false, errors.New(fmt.Sprintf("NTLM auth api returned with HTTP code: %d, %s", statusCode, string(body)))
	}
	return true, nil
}

func CheckMachineAccountWithGivenPassword(ctx context.Context, backendHostPort string, password string) (bool, error) {
	url := "http://" + backendHostPort + "/ntlm/connect"

	client := &http.Client{
		Timeout: 16 * time.Second,
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
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return false, err
	}
	if statusCode != http.StatusOK {
		return false, errors.New(fmt.Sprintf("NTLM auth api returned with HTTP code: %d, %s", statusCode, string(body)))
	}
	return true, nil
}

func ReportMSEvent(ctx context.Context, backendHostPort string, jsonData any) error {
	url := "http://" + backendHostPort + "/event/report"

	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	jsonBytes, _ := json.Marshal(jsonData)
	buffer := bytes.NewBuffer(jsonBytes)

	response, err := client.Post(url, "application/json", buffer)
	if err != nil {
		return err
	}

	defer response.Body.Close()
	statusCode := response.StatusCode
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return err
	}
	if statusCode == http.StatusOK || statusCode == http.StatusAccepted {
		return nil
	}
	return errors.New(fmt.Sprintf("NTLM event report API replied with HTTP code: %d, %s", statusCode, string(body)))
}
