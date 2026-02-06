package discovernetworkdevice

import (
	"context"
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

type CredType string

const (
	CRED_TYPE_SNMP_V1  CredType = "snmp_v1"
	CRED_TYPE_SNMP_V2C CredType = "snmp_v2c"
)

var credTypeList = []CredType{CRED_TYPE_SNMP_V1, CRED_TYPE_SNMP_V2C}

// Credential contains information about SNMP credential
type SnmpCred struct {
	Version       CredType `json:"version"`
	CommunityRead string   `json:"community_read"`
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
	Credentials []SnmpCred `json:"credentials"`
	Addresses   []string   `json:"addresses"`
	Options     Options    `json:"options"`
}

// Device contains informations found about a device on an IP address
type Device struct {
	Credential SnmpCred `json:"credential"`
	Driver     string   `json:"driver"`
	Ip         string   `json:"ip"`
	Vendor     string   `json:"vendor"`
	Os         string   `json:"os"`
	Version    string   `json:"version"`
	System     string   `json:"system"` // the whole SNMP sysDesc OID
	Oid        string   `json:"oid"`    // oid of the device return by the SNMP request
	Hostname   string   `json:"hostname"`
}

// Driver map devices.json file data
type Driver struct {
	Name      string `json:"name"`
	Vendor    string `json:"vendor"`
	Os        string `json:"os"`
	Driver    string `json:"driver,omitempty"` // driver id in Scrapli lib
	SysOidReg string `json:"sysOID,omitempty"`
	SysOsReg  string `json:"sysOS,omitempty"`
	SysVerReg string `json:"sysVersion,omitempty"`
}

// ScanResult contains details about failed SNMP requests
type SnmpResult struct {
	Address string `json:"address"`
	Message string `json:"message"`
}

// ScanResponse is the scan response
type ScanResponse struct {
	SnmpResults []SnmpResult `json:"snmp_results"` // possible device but we were not able to reach them
	Devices     []Device     `json:"devices"`      // devices found
}

// Drivers is the type of the devices.json file
type drivers struct {
	Devices []Driver `json:"devices"`
}

type snmpOutputData struct {
	SysDesc     string
	SysOid      string
	HostnameOid string
}

const (
	// default values, can be changed by Options
	maxThreads  = 32
	snmpRetry   = 1 // 0 = no retry, 1 = 1 retry
	snmpTimeout = 1 // in seconds
	snmpPort    = 161
	// fixed
	snmpTransport = "udp"
	sysDescrOid   = ".1.3.6.1.2.1.1.1.0"
	sysOidOid     = ".1.3.6.1.2.1.1.2.0"
	// uptimeOid     = ".1.3.6.1.2.1.1.3.0"
	hostnameOid = ".1.3.6.1.2.1.1.5.0"
	driverFile  = "/usr/local/pf/conf/discover-network-device/drivers.json"
)

// Macth a CIDR iPv4 like 192.168.40.0/28
var ipReg = regexp.MustCompile(`^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/(3[0-2]|[1-2][0-9]|[0-9]))?$`)

// readDriverFile reads the json file containing drivers informations
func readDriverFile(filename string) (*drivers, error) {
	var data drivers
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

// estimateTimeOfScan estime the maximum amount of time the scan will take, in seconds
// Addresses and options must have been validated at this point
func estimateTimeOfScan(nAddresses int, options Options) int {
	timePerAddress := options.SnmpTimeout + options.SnmpRetry*options.SnmpTimeout
	maxAddrPerThread := nAddresses/options.MaxThreads + 1
	return maxAddrPerThread * timePerAddress
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
	tmp := slices.Collect(maps.Keys(lst))
	slices.Sort(tmp)
	return tmp, nil
}

func checkCredentials(creds []SnmpCred) error {
	for _, cred := range creds {
		if len(cred.CommunityRead) == 0 {
			return fmt.Errorf("Read community string is empty")
		}
		if !slices.Contains(credTypeList, cred.Version) {
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
		opts.SnmpRetry = snmpRetry
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

func getSnmpData(snmp *gosnmp.GoSNMP, snmpData *snmpOutputData, addr string) (SnmpResult, bool) {
	oid_reqs := []string{sysDescrOid, sysOidOid, hostnameOid}
	err := snmp.Connect()
	if err != nil {
		return SnmpResult{Address: addr, Message: fmt.Sprintf("SNMP initialization failed: %v", err)}, true
	}
	defer snmp.Close()
	data, err := snmp.Get(oid_reqs)
	if err != nil {
		// ignore timeout events. No log for an address = timeout
		if !strings.Contains(err.Error(), "request timeout") {
			return SnmpResult{Address: addr, Message: fmt.Sprintf("SNMP Get failed: %v", err)}, true
		}
		return SnmpResult{}, true
	}
	sysDesc, err := getSnmpVarAsStr(data.Variables[0]) // sysDesc
	if err != nil {
		return SnmpResult{Address: addr, Message: fmt.Sprintf("SNMP SysDesc: %v", err)}, true
	}
	sysOid, err := getSnmpVarAsStr(data.Variables[1]) // sysOid
	if err != nil {
		return SnmpResult{Address: addr, Message: fmt.Sprintf("SNMP SysOid: %v", err)}, true
	}
	hostnameOid, err := getSnmpVarAsStr(data.Variables[2]) // hostnameOid
	if err != nil {
		return SnmpResult{Address: addr, Message: fmt.Sprintf("SNMP HostnameOid: %v", err)}, true
	}
	snmpData.SysDesc = sysDesc
	snmpData.SysOid = sysOid
	snmpData.HostnameOid = hostnameOid
	return SnmpResult{}, false
}

func scanPart(ctx context.Context, wg *sync.WaitGroup, out chan Device, snmpErr chan SnmpResult, progressChan chan int,
	drivers []Driver, payload Payload, addresses []string) {
	opts := payload.Options
	creds := payload.Credentials
	snmp := gosnmp.GoSNMP{}
	snmp.Port = uint16(opts.SnmpPort)
	snmp.Transport = snmpTransport
	snmp.Retries = opts.SnmpRetry
	snmp.Timeout = time.Second * time.Duration(opts.SnmpTimeout)
	snmp.ExponentialTimeout = false
	defer wg.Done()
	for _, addr := range addresses {
		progressChan <- 1
		snmp.Target = addr
		for _, cred := range creds {
			switch cred.Version {
			case CRED_TYPE_SNMP_V1:
				snmp.Version = gosnmp.Version1
			case CRED_TYPE_SNMP_V2C:
				snmp.Version = gosnmp.Version2c
			default: // should not happen, it was check before
				continue
			}
			snmp.Community = cred.CommunityRead
			snmpData := snmpOutputData{}
			snmpResult, errorHappened := getSnmpData(&snmp, &snmpData, addr)
			if errorHappened { // special case when we ignore error
				select {
				case <-ctx.Done():
					fmt.Println("Done at start")
					return
				case snmpErr <- snmpResult:
					continue
				}
			}
			found := -1
			for i, driver := range drivers {
				regOs := regexp.MustCompile(driver.SysOsReg)
				regOid := regexp.MustCompile(driver.SysOidReg)
				if regOs.MatchString(snmpData.SysDesc) && regOid.MatchString(snmpData.SysOid) {
					found = i
					break
				}
			}
			foundDevice := Device{
				Ip:         addr,
				System:     snmpData.SysDesc,
				Oid:        snmpData.SysOid,
				Hostname:   snmpData.HostnameOid,
				Credential: cred,
			}
			if found != -1 {
				driver := drivers[found]
				var ver string
				if len(driver.SysVerReg) > 0 {
					regVer := regexp.MustCompile(driver.SysVerReg)
					ver = regVer.FindString(snmpData.SysDesc)
					if len(ver) < 3 { // minimum of "x.y"
						snmpErr <- SnmpResult{Address: addr, Message: "Cannot parse version"}
						// kinda bad ver? ignore
						ver = ""
					}
				}
				ver = strings.TrimSpace(ver)
				foundDevice.Driver = driver.Driver
				foundDevice.Vendor = driver.Vendor
				foundDevice.Os = driver.Os
				foundDevice.Version = ver
			} // We found a device, but no match, send raw data
			select {
			case <-ctx.Done():
				return
			case out <- foundDevice:
			}
		}
	}
}

// Scan is the main entry of the network scan
func SnmpScan(ctx context.Context, payload Payload, progressCb func(int, string)) (*ScanResponse, error) {
	drivers, err := readDriverFile(driverFile)
	if err != nil {
		return nil, fmt.Errorf("Bad drivers file: %s", err.Error())
	}
	addresses, err := resolveAddresses(payload.Addresses)
	if err != nil {
		return nil, fmt.Errorf("Bad addresses: %s", err.Error())
	}
	if err := checkCredentials(payload.Credentials); err != nil {
		return nil, fmt.Errorf("Bad credentials: %s", err.Error())
	}
	if err := checkOptions(&payload.Options); err != nil {
		return nil, fmt.Errorf("Bad options: %s", err.Error())
	}
	estimatedTimeOfScan := estimateTimeOfScan(len(addresses), payload.Options)
	progressCb(1, fmt.Sprintf("%d addresses to scan. Estimated time: %dm%ds", len(addresses), estimatedTimeOfScan/60, estimatedTimeOfScan%60))
	var wgOut sync.WaitGroup
	var resp ScanResponse
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
			if len(snmpErr.Address) > 0 { // filter unwanted errors
				resp.SnmpResults = append(resp.SnmpResults, snmpErr)
			}
		}
	})
	wgOut.Go(func() {
		// dont send duplicate %, send only a 5 step increase, from 5% to 100%
		n := 0
		alreadySeen := make(map[int]bool)
		for range progressChan {
			n += 1
			percentDone := max(min(int(float32(n)/float32(len(addresses))*100.0+1.0), 100), 1)
			if percentDone%5 == 0 {
				if _, ok := alreadySeen[percentDone]; !ok {
					alreadySeen[percentDone] = true
					addressesRemaining := len(addresses) - n
					estimatedTimeOfScan := estimateTimeOfScan(addressesRemaining, payload.Options)
					progressCb(int(percentDone), fmt.Sprintf("%d addresses remaining. Estimated time: %dm%ds", addressesRemaining, estimatedTimeOfScan/60, estimatedTimeOfScan%60))
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
		go scanPart(ctx, &wg, deviceFoundChan, snmpErrChan, progressChan, drivers.Devices, payload, addresses[lid:rid])
	}
	wg.Wait()
	close(deviceFoundChan)
	close(snmpErrChan)
	close(progressChan)
	wgOut.Wait()
	progressCb(100, "Done!")
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	return &resp, nil
}
