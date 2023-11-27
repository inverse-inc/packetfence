package ntlm

import (
	"context"
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
	url := "http://127.0.0.1:" + backendPort + "/ntlm/connect"

	client := &http.Client{
		Timeout: 2 * time.Second,
	}
	response, err := client.Get(url)
	if err != nil {
		return false, err
	}

	defer response.Body.Close()
	statusCode := response.StatusCode
	_, err = ioutil.ReadAll(response.Body)
	if err != nil {
		return false, err
	}
	if statusCode != http.StatusOK {
		return false, errors.New(fmt.Sprintf("NTLM auth api returned with HTTP code: %d", statusCode))
	}
	return true, nil
}
