package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"net/http"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/goji/httpauth"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/sbinet/go-python"
)

type Info struct {
	Status    string `json:"status"`
	WmiResult map[string]string
}

var ctx = context.Background()
var webservices pfconfigdriver.PfConfWebservices
var WmiResult map[string]string

func init() {
	err := python.Initialize()
	if err != nil {
		panic(err.Error())
	}
}

type Test struct {
	Str2Py func(string) *python.PyObject
	Py2Str func(*python.PyObject) string
}

func (test *Test) ImportModule(dir, name string) *python.PyObject {
	module := python.PyImport_ImportModule("sys")
	path := module.GetAttrString("path")
	python.PyList_Insert(path, 0, test.Str2Py(dir))
	return python.PyImport_ImportModule(name)
}

func NewTest() *Test {
	err := python.Initialize()
	if err != nil {
		panic(err.Error())
	}
	test := &Test{
		Str2Py: python.PyString_FromString,
		Py2Str: python.PyString_AsString,
	}
	return test
}

func main() {

	webservices = readWebservicesConfig()

	router := mux.NewRouter()
	router.HandleFunc("/scanwmi/{scanname:(?:[^/]*)}/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}", scan).Methods("POST")
	http.Handle("/", httpauth.SimpleBasicAuth(webservices.User, webservices.Pass)(router))
	// Api
	cfg := &tls.Config{
		MinVersion:               tls.VersionTLS12,
		CurvePreferences:         []tls.CurveID{tls.CurveP521, tls.CurveP384, tls.CurveP256},
		PreferServerCipherSuites: true,
		CipherSuites: []uint16{
			tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,
			tls.TLS_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_RSA_WITH_AES_256_CBC_SHA,
		},
	}
	srv := &http.Server{
		Addr:         ":22224",
		Handler:      router,
		TLSConfig:    cfg,
		TLSNextProto: make(map[string]func(*http.Server, *tls.Conn, http.Handler), 0),
	}

	// detectMembers()
	daemon.SdNotify(false, "READY=1")

	go func() {
		interval, err := daemon.SdWatchdogEnabled(false)
		if err != nil || interval == 0 {
			return
		}
		for {
			req, err := http.NewRequest("GET", "https://127.0.0.1:22224", nil)
			req.SetBasicAuth(webservices.User, webservices.Pass)
			tr := &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
			}
			cli := &http.Client{Transport: tr}
			_, err = cli.Do(req)
			if err == nil {
				daemon.SdNotify(false, "WATCHDOG=1")
			}
			time.Sleep(interval / 3)
		}
	}()
	srv.ListenAndServeTLS("/usr/local/pf/conf/ssl/server.crt", "/usr/local/pf/conf/ssl/server.key")

}

func scan(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	IP := vars["ip"]
	ScanName := vars["scanname"]

	WmiResult = make(map[string]string)

	var keyConfScan pfconfigdriver.PfconfigKeys
	keyConfScan.PfconfigNS = "config::Scan"
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfScan)

	var ConfScan pfconfigdriver.ScanConf

	var ConfWmi pfconfigdriver.WmiRulesConf

	for _, key := range keyConfScan.Keys {

		ConfScan.PfconfigHashNS = key

		pfconfigdriver.FetchDecodeSocket(ctx, &ConfScan)
		if key == ScanName {
			for _, WmiRule := range ConfScan.WMIRules {

				ConfWmi.PfconfigNS = "config::Wmi"
				ConfWmi.PfconfigHashNS = WmiRule
				pfconfigdriver.FetchDecodeSocket(ctx, &ConfWmi)
				result := launchScan(ConfWmi, ConfScan, IP)
				WmiResult[WmiRule] = result
			}
			break
		}
	}
	var result = map[string][]*Info{
		"result": {
			&Info{WmiResult: WmiResult, Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

// launchScan
func launchScan(ConfWmi pfconfigdriver.WmiRulesConf, ConfScan pfconfigdriver.ScanConf, IP string) string {
	test := NewTest()
	_module := test.ImportModule("./", "wmi")
	_attr := _module.GetAttrString("wmitest")

	_args := python.PyTuple_New(6)
	python.PyTuple_SET_ITEM(_args, 0, test.Str2Py(ConfScan.Domain))
	python.PyTuple_SET_ITEM(_args, 1, test.Str2Py(ConfScan.Username))
	python.PyTuple_SET_ITEM(_args, 2, test.Str2Py(ConfScan.Password))
	python.PyTuple_SET_ITEM(_args, 3, test.Str2Py(IP))
	python.PyTuple_SET_ITEM(_args, 4, test.Str2Py(ConfWmi.Namespace))
	python.PyTuple_SET_ITEM(_args, 5, test.Str2Py(ConfWmi.Request))

	result := _attr.Call(_args, python.Py_None)

	return test.Py2Str(result)

}

// readWebservicesConfig read pfconfig webservices configuration
func readWebservicesConfig() pfconfigdriver.PfConfWebservices {
	var webservices pfconfigdriver.PfConfWebservices
	webservices.PfconfigNS = "config::Pf"
	webservices.PfconfigMethod = "hash_element"
	webservices.PfconfigHashNS = "webservices"

	pfconfigdriver.FetchDecodeSocket(ctx, &webservices)
	return webservices
}
