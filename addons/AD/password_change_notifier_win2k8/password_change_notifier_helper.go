package main

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"strings"
)

type Config struct {
	BaseURL   string `json:"base_url"`
	Username  string `json:"username"`
	Password  string `json:"password"`
	DomainID  string `json:"domain_id"`
	BatchSize int    `json:"batch_size"`
}

func main() {
	var cfg Config
	configJson, err := ioutil.ReadFile("config.json")
	if err != nil {
		fmt.Printf("Unable to load settings from config.json: %s", err.Error())
		os.Exit(1)
	}
	err = json.Unmarshal(configJson, &cfg)
	if err != nil {
		fmt.Println("Unable to unmarshal config")
		os.Exit(1)
	}
	cfg.BaseURL = strings.TrimRight(cfg.BaseURL, "/")
	fmt.Println("-- loaded config:")
	fmt.Println("  base_url  : ", cfg.BaseURL)
	fmt.Println("  username  : ", cfg.Username)
	fmt.Println("  password  : ", cfg.Password)
	fmt.Println("  domain_id : ", cfg.DomainID)
	fmt.Println("  batch_size: ", cfg.BatchSize)

	events, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Printf("Error reading events from stdin: %s", err.Error())
		os.Exit(1)
	}
	fmt.Println("-- events read from stdin:")
	fmt.Println(string(events))

	// get token
	tokenUrl := cfg.BaseURL + "/api/v1/login"
	tokenJson := map[string]string{
		"username": cfg.Username,
		"password": cfg.Password,
	}
	tokenPayload, err := json.Marshal(tokenJson)
	if err != nil {
		fmt.Println("Error marshalling JSON for authentication:", err)
		os.Exit(1)
	}

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	client := &http.Client{Transport: tr}

	response, err := client.Post(tokenUrl, "application/json", bytes.NewBuffer(tokenPayload))
	if err != nil {
		fmt.Println("Error while getting token: ", err)
		os.Exit(1)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		fmt.Println("Authentication failed: HTTP Status ", response.StatusCode)
		os.Exit(1)
	}
	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		fmt.Println("Authentication failed, error reading response body: ", err)
		os.Exit(1)
	}
	type TokenS struct {
		Token string `json:"token"`
	}
	var token TokenS
	err = json.Unmarshal(body, &token)
	if err != nil {
		fmt.Println("Authentication failed, error while unmarshal token JSON:", err)
		os.Exit(1)
	}

	// report events
	notifierUrl := cfg.BaseURL + "/api/v1/ntlm/event-report"
	req, err := http.NewRequest("POST", notifierUrl, bytes.NewBuffer(events))
	if err != nil {
		fmt.Println("Event reporting failed: Error creating request:", err)
		os.Exit(1)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", token.Token)

	res, err := client.Do(req)
	if err != nil {
		fmt.Println("Error while reporting Windows Events: ", err)
		os.Exit(1)
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusAccepted && res.StatusCode != http.StatusOK {
		fmt.Println("Event reporting failed: HTTP Status ", res.StatusCode)
		os.Exit(1)
	}
	body, err = ioutil.ReadAll(res.Body)
	if err != nil {
		fmt.Println("Event reporting failed, error reading response body: ", err)
		os.Exit(1)
	}
	fmt.Println("Successfully reported Windows events: ", string(body))
}
