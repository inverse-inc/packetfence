package discovernetworkdevice

import (
	"encoding/json"
	"fmt"
	"maps"
	"math"
	"net/netip"
	"os"
	"regexp"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gosnmp/gosnmp"
)

// Credential contains information about SNMP credential
type Credential struct {
	Type     string `json:"type"`
	SnmpRead string `json:"snmp_read"`
}

// Options sent in request (or default values)
type Options struct {
	MaxThreads  int `json:"max_threads,omitempty"`
	SnmpTimeout int `json:"snmp_timeout,omitempty"` // in seconds
	SnmpRetry   int `json:"snmp_retry,omitempty"`
	SnmpPort    int `json:"snmp_port,omitempty"`
}

// Payload is the payload sent by the client
type Payload struct {
	Credentials []Credential `json:"credentials"`
	Addresses   []string     `json:"addresses"`
	Options     Options      `json:"options"`
}

// Device contains informations found about a device on an IP address
type Device struct {
	Credential Credential `json:"credential"`
	Driver     string     `json:"driver"`
	Ip         string     `json:"ip"`
	Vendor     string     `json:"vendor"`
	Os         string     `json:"os"`
	Version    string     `json:"version"`
	System     string     `json:"system"` // the whole SNMP sysDesc OID
	Oid        string     `json:"oid"`    // oid of the device return by the SNMP request
}

// Driver map devices.json file data
type Driver struct {
	Name      string `json:"name"`
	Vendor    string `json:"vendor"`
	Os        string `json:"os,omitempty"`
	Driver    string `json:"driver,omitempty"`
	SysOidReg string `json:"sysOID"`
	SysOsReg  string `json:"sysOS"`
	SysVerReg string `json:"sysVersion,omitempty"`
}

// ScanResult contains details about failed SNMP requests
type SnmpResult struct {
	Address string `json:"address"`
	Error   string `json:"error"`
}

// ScanResponse is the scan response
type ScanResponse struct {
	SnmpResult []SnmpResult `json:"snmp_result"`
	Devices    []Device     `json:"devices"`
}

// Drivers is the type of the devices.json file
type Drivers struct {
	Devices []Driver `json:"devices"`
}

const (
	// default values, can be changed by Options
	maxThreads  = 32
	snmpRetries = 1
	snmpTimeout = 1 // in seconds
	snmpPort    = 161
	// fixed
	snmpTransport = "udp"
	sysDescrOid   = ".1.3.6.1.2.1.1.1.0"
	sysOidOid     = ".1.3.6.1.2.1.1.2.0"
	driverFile    = "/usr/local/pf/conf/discover-network-device/drivers.json"
)

var credTypeList = []string{"snmp_v1", "snmp_v2c"}
var ipReg = regexp.MustCompile(`^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/(3[0-2]|[1-2][0-9]|[0-9]))?$`)

// readDriverFile reads the json file containing drivers informations
func readDriverFile(filename string) (*Drivers, error) {
	var data Drivers
	bytes, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(bytes, &data)
	if err != nil {
		return nil, err
	}
	for _, device := range data.Devices {
		if len(device.Name) < 2 {
			return nil, fmt.Errorf("Device %s has an invalid name", device.Name)
		}
		if len(device.Vendor) < 2 {
			return nil, fmt.Errorf("Device %s has an invalid vendor", device.Name)
		}
		if len(device.Os) < 2 {
			return nil, fmt.Errorf("Device %s has an invalid os", device.Name)
		}
		if len(device.Driver) == 1 { // 0 = not set, 2+ = ok, so 1=invalid
			return nil, fmt.Errorf("Device %s has an invalid driver", device.Name)
		}
		if _, err := regexp.Compile(device.SysOidReg); err != nil {
			return nil, fmt.Errorf("Device %s has an invalid sysOID (%s)", device.Name, err.Error())
		}
		if _, err := regexp.Compile(device.SysOsReg); err != nil {
			return nil, fmt.Errorf("Device %s has an invalid sysOS (%s)", device.Name, err.Error())
		}
		if _, err := regexp.Compile(device.SysVerReg); err != nil {
			return nil, fmt.Errorf("Device %s has an invalid sysVersion (%s)", device.Name, err.Error())
		}
	}
	return &data, nil
}

// checkIp check ipv4 format with optionnal CIDR
func checkIp(ip string) bool {
	return ipReg.MatchString(ip)
}

// getSnmpVarAsStr transform an gosnmp.SnmpPDU response to a string
func getSnmpVarAsStr(variable gosnmp.SnmpPDU) (string, error) {
	switch variable.Type {
	case gosnmp.OctetString:
		return string(variable.Value.([]byte)), nil
	case gosnmp.ObjectIdentifier:
		return variable.Value.(string), nil
	default:
		return "", fmt.Errorf("SNMP PDU not supported type: %s", variable.Type.String())
	}
}

func generateIpCidrList(cidrStr string) ([]string, error) {
	prefix, err := netip.ParsePrefix(cidrStr)
	if err != nil {
		return nil, err
	}
	var ips []string
	for addr := prefix.Addr(); prefix.Contains(addr); addr = addr.Next() {
		tmp := addr.As4()
		if tmp[3] != 0 && tmp[3] != 255 {
			ips = append(ips, addr.String())
		}
	}
	return ips, nil
}

// resolveAddresses expand CIDR if needed, and construct an array containing all addresses to scan
func resolveAddresses(addresses []string) ([]string, error) {
	if len(addresses) == 0 {
		return nil, fmt.Errorf("At least 1 address required")
	}
	lst := make(map[string]bool, 0)
	for _, addr := range addresses {
		if !checkIp(addr) {
			return nil, fmt.Errorf("Bad ip format: %s", addr)
		}
		splitIpCidr := strings.Split(addr, "/")
		if len(splitIpCidr) == 1 {
			lst[addr] = true
		} else {
			cidr, err := strconv.Atoi(splitIpCidr[1])
			if err != nil {
				return nil, err
			}
			if cidr < 16 || cidr > 32 {
				return nil, fmt.Errorf("IP CIDR must be between 16 and 32")
			}
			ips, err := generateIpCidrList(addr)
			if err != nil {
				return nil, err
			}
			for _, ip := range ips {
				lst[ip] = true
			}
		}
	}
	return slices.Collect(maps.Keys(lst)), nil
}

func checkCredentials(creds []Credential) error {
	for _, cred := range creds {
		if len(cred.SnmpRead) == 0 {
			return fmt.Errorf("Read community string is empty")
		}
		if !slices.Contains(credTypeList, cred.Type) {
			return fmt.Errorf("Credential type not supported")
		}
	}
	return nil
}

func checkOptions(opts *Options) error {
	if opts.MaxThreads == 0 { // default or auto value
		opts.MaxThreads = max(runtime.NumCPU()*4, maxThreads)
	} else if opts.MaxThreads < 0 || opts.MaxThreads > 256 {
		return fmt.Errorf("MaxThread must be in range [0-256]")
	}
	if opts.SnmpPort == 0 { // default port
		opts.SnmpPort = snmpPort
	} else if opts.SnmpPort < 0 || opts.SnmpPort > math.MaxUint16 {
		return fmt.Errorf("SnmpPort must be in range [0-%d]", math.MaxUint16)
	}
	if opts.SnmpRetry == 0 { // default 1 retry
		opts.SnmpRetry = snmpRetries
	} else if opts.SnmpRetry < 0 || opts.SnmpRetry > 10 {
		return fmt.Errorf("SnmpRetry must be in range [0-10]")
	}
	if opts.SnmpTimeout == 0 { // default timeout
		opts.SnmpTimeout = snmpTimeout
	} else if opts.SnmpTimeout < 0 || opts.SnmpTimeout > 10 {
		return fmt.Errorf("SnmpTimeout must be in range [0-10] seconds")
	}
	return nil
}

func scanPart(wg *sync.WaitGroup, out chan Device, snmpErr chan SnmpResult, progressChan chan int,
	drivers []Driver, creds []Credential, opts Options, addresses []string) {
	snmp := gosnmp.GoSNMP{}
	snmp.Port = uint16(opts.SnmpPort)
	snmp.Transport = snmpTransport
	snmp.Retries = opts.SnmpRetry
	snmp.Timeout = time.Second * time.Duration(opts.SnmpTimeout)
	snmp.ExponentialTimeout = false
	oid_reqs := []string{sysDescrOid, sysOidOid}
	defer wg.Done()
	for _, addr := range addresses {
		progressChan <- 1
		snmp.Target = addr
		var sysDesc string
		for _, cred := range creds {
			switch cred.Type {
			case "snmp_v1":
				snmp.Version = gosnmp.Version1
			case "snmp_v2c":
				snmp.Version = gosnmp.Version2c
			default: // should not happen, it was check before
				snmpErr <- SnmpResult{Address: addr, Error: "SNMP version not supported"}
				continue
			}
			snmp.Community = cred.SnmpRead
			err := snmp.Connect()
			if err != nil {
				snmpErr <- SnmpResult{Address: addr, Error: fmt.Sprintf("SNMP initialization failed: %v", err)}
				continue
			}
			defer snmp.Close()
			data, err := snmp.Get(oid_reqs)
			if err != nil {
				// ignore timeout events. No log for an address = timeout
				if !strings.Contains(err.Error(), "request timeout") {
					snmpErr <- SnmpResult{Address: addr, Error: fmt.Sprintf("SNMP Get failed: %v", err)}
				}
				continue
			}
			sysDesc, err = getSnmpVarAsStr(data.Variables[0]) // sysDesc
			if err != nil {
				snmpErr <- SnmpResult{Address: addr, Error: fmt.Sprintf("SNMP SysDesc: %v", err)}
				continue
			}
			sysOid, err := getSnmpVarAsStr(data.Variables[1]) // sysOid
			if err != nil {
				snmpErr <- SnmpResult{Address: addr, Error: fmt.Sprintf("SNMP SysOid: %v", err)}
				continue
			}
			found := -1
			for i, driver := range drivers {
				regOs := regexp.MustCompile(driver.SysOsReg)
				regOid := regexp.MustCompile(driver.SysOidReg)
				if regOs.MatchString(sysDesc) && regOid.MatchString(sysOid) {
					found = i
					break
				}
			}
			if found != -1 {
				driver := drivers[found]
				var ver string
				if len(driver.SysVerReg) > 0 {
					regVer := regexp.MustCompile(driver.SysVerReg)
					ver = regVer.FindString(sysDesc)
					if len(ver) < 3 { // minimum of "x.y"
						snmpErr <- SnmpResult{Address: addr, Error: "Cannot parse version"}
						// kinda bad ver? ignore
						ver = ""
					}
				}
				ver = strings.TrimSpace(ver)
				out <- Device{
					Ip:         addr,
					Driver:     driver.Driver,
					Vendor:     driver.Vendor,
					Os:         driver.Os,
					Version:    ver,
					System:     sysDesc,
					Oid:        sysOid,
					Credential: Credential{Type: cred.Type, SnmpRead: cred.SnmpRead},
				}
			} else {
				// We have a SNMP response, but no match found, send raw data
				out <- Device{
					Ip:         addr,
					System:     sysDesc,
					Oid:        sysOid,
					Credential: Credential{Type: cred.Type, SnmpRead: cred.SnmpRead},
				}
			}
		}
	}
}

// Scan is the main entry of the network scan
func SnmpScan(payload Payload, progressCb func(int)) (*ScanResponse, error) {
	progressCb(1)
	var resp ScanResponse
	drivers, err := readDriverFile(driverFile)
	if err != nil {
		return nil, err
	}
	addresses, err := resolveAddresses(payload.Addresses)
	if err != nil {
		return nil, err
	}
	if err := checkCredentials(payload.Credentials); err != nil {
		return nil, fmt.Errorf("Bad credentials: %v", err)
	}
	if err := checkOptions(&payload.Options); err != nil {
		return nil, fmt.Errorf("Bad options: %v", err)
	}
	var wgOut sync.WaitGroup
	deviceFoundChan := make(chan Device)
	snmpErrChan := make(chan SnmpResult)
	progressChan := make(chan int)
	wgOut.Go(func() {
		for device := range deviceFoundChan {
			resp.Devices = append(resp.Devices, device)
		}
	})
	wgOut.Go(func() {
		for snmpErr := range snmpErrChan {
			resp.SnmpResult = append(resp.SnmpResult, snmpErr)
		}
	})
	wgOut.Go(func() {
		// dont send duplicate %, send only a 5 step increase
		n := 0
		alreadySeen := make(map[int]bool)
		for range progressChan {
			n += 1
			percentDone := int(float32(n)/float32(len(addresses))*99.0 + 1.0)
			if percentDone%5 == 0 {
				if _, ok := alreadySeen[percentDone]; !ok {
					alreadySeen[percentDone] = true
					progressCb(int(percentDone))
				}
			}
		}
	})
	nThreads := payload.Options.MaxThreads
	offset := len(addresses)/nThreads + 1
	var wg sync.WaitGroup
	for i := range nThreads {
		lid := i * offset
		if lid > len(addresses) { // too many threads for low addresses count
			break
		}
		rid := min(lid+offset, len(addresses))
		wg.Add(1)
		go scanPart(&wg, deviceFoundChan, snmpErrChan, progressChan, drivers.Devices, payload.Credentials, payload.Options, addresses[lid:rid])
	}
	wg.Wait()
	close(deviceFoundChan)
	close(snmpErrChan)
	close(progressChan)
	wgOut.Wait()
	progressCb(100)
	return &resp, nil
}
