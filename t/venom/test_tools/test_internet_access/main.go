package main

import (
	"crypto/tls"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
)

func main() {

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{
			PreferServerCipherSuites: true,
			InsecureSkipVerify:       true,
		},
	}

	client := http.Client{tr, nil, nil, 0}

	resp, err := client.Get("https://cnn.com/")

	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	b, err := ioutil.ReadAll(resp.Body)

	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	resp.Body.Close()

	if len(b) < 500 {
		fmt.Println("Page to small")
		os.Exit(1)
	}

}
