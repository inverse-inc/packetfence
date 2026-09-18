package pfconfigdriver

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"reflect"
	"regexp"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	//"github.com/davecgh/go-spew/spew"
)

const pfconfigSocketPath string = "/usr/local/pf/var/run/pfconfig.sock"

const pfconfigTestSocketPath string = "/usr/local/pf/var/run/pfconfig-test.sock"

var pfconfigSocketPathCache string

var SocketTimeout time.Duration = 60 * time.Second

var myHostname string

var myClusterName string

var clusterSummary *ClusterSummary

var nsHasOverlayRe = regexp.MustCompile(`.*\(.*\)$`)

var isNamespaceConfiguration = regexp.MustCompile(`^Pfconfig`)
var isNotNamespaceConfiguration = regexp.MustCompile(`(^PfconfigKeys$)`)

func init() {
	var err error
	myHostname, err = os.Hostname()
	sharedutils.CheckError(err)
}

// Get the pfconfig socket path depending on whether or not we're in testing
// Since the environment is not bound to change at runtime, the socket path is computed once and cached in pfconfigSocketPathCache
// If the socket should be re-computed, empty out pfconfigSocketPathCache and run this function
func getPfconfigSocketPath() string {
	if pfconfigSocketPathCache != "" {
		// Do nothing, cache is populated, will be returned below
	} else if sharedutils.EnvOrDefault("PFCONFIG_TESTING", "") == "" {
		pfconfigSocketPathCache = pfconfigSocketPath
	} else {
		fmt.Println("Test flag is on. Using pfconfig test socket path.")
		pfconfigSocketPathCache = pfconfigTestSocketPath
	}
	return pfconfigSocketPathCache
}

// Struct that encapsulates the necessary information to do a query to pfconfig
type Query struct {
	encoding string
	method   string
	ns       string
	basens   string
}

// Get the payload to send to pfconfig based on the Query attributes
// Also sets the payload attribute at the same time
func (q *Query) GetPayload() string {
	j, err := json.Marshal(struct {
		Encoding string `json:"encoding"`
		Method   string `json:"method"`
		NS       string `json:"key"`
	}{
		Encoding: q.encoding,
		Method:   q.method,
		NS:       q.ns,
	})
	sharedutils.CheckError(err)
	return string(j) + "\n"
}

// Get a string identifier of the query
func (q *Query) GetIdentifier() string {
	return fmt.Sprintf("%s|%s", q.method, q.ns)
}

// Connect to the pfconfig socket
// If it fails to connect, it will try it every second up to the time defined in SocketTimeout
// After SocketTimeout is reached, this will panic
func connectSocket(ctx context.Context) net.Conn {

	timeoutChan := time.After(SocketTimeout)

	proto := sharedutils.EnvOrDefault("PFCONFIG_PROTO", "tcp")

	var c net.Conn
	err := errors.New("Not yet connected")
	for err != nil {
		select {
		case <-timeoutChan:
			panic("Can't connect to pfconfig socket")
		default:
			// We try to connect to the pfconfig socket
			// If we fail, we will wait a second before leaving this scope
			// Otherwise, we continue and the for loop will detect the connection is valid since err will be nil
			switch proto {
			case "tcp":
				host := sharedutils.EnvOrDefault("PFCONFIG_TCP_HOST", "127.0.0.1")
				port := sharedutils.EnvOrDefault("PFCONFIG_TCP_PORT", "44444")
				c, err = net.Dial("tcp", fmt.Sprintf("%s:%s", host, port))
			case "unix":
				c, err = net.Dial("unix", getPfconfigSocketPath())
			default:
				panic("Unrecognized protocol for pfconfigdriver")
			}
			if err != nil {
				log.LoggerWContext(ctx).Error("Cannot connect to pfconfig socket..." + err.Error())
				time.Sleep(1 * time.Second)
			}
		}
	}

	return c
}

// Fetch data from the pfconfig socket for a string payload
// Returns the bytes received from the socket
func FetchSocket(ctx context.Context, payload string) []byte {
	c := connectSocket(ctx)

	// Send our query in the socket
	io.WriteString(c, payload)

	var buf bytes.Buffer
	buf.ReadFrom(c)

	// First 4 bytes are a little-endian representing the length of the payload
	var length uint32
	binary.Read(&buf, binary.LittleEndian, &length)

	// Read the response given the length provided by pfconfig
	response := make([]byte, length)
	buf.Read(response)

	// Validate the response has the length that was declared by pfconfig
	if uint32(len(response)) != length {
		panic(fmt.Sprintf("Got invalid length response from pfconfig %d expected, received %d", length, len(response)))
	}
	c.Close()
	return response
}

// Lookup the pfconfig metadata for a specific field
// If there is a non-zero value in the field, it will be taken
// Otherwise it will take the value in the val tag of the field
func metadataFromField(ctx context.Context, param interface{}, fieldName string) string {
	var ov reflect.Value

	ov = reflect.ValueOf(param)
	for ov.Kind() == reflect.Ptr || ov.Kind() == reflect.Interface {
		ov = ov.Elem()
	}

	// We check if the field was set to a value as this will overide the value in the tag
	// At the same time, we check if the field exists and early exit with the empty string if it doesn't
	field := reflect.Value(ov.FieldByName(fieldName))
	if !field.IsValid() {
		return ""
	}

	userVal := field.Interface()
	if userVal != "" {
		return userVal.(string)
	}

	ot := ov.Type()
	if field, ok := ot.FieldByName(fieldName); ok {
		// The val tag defines the «default» value the metadata field should have
		// If the val tag has a value of "-", then a user value was expected and this will panic
		val := field.Tag.Get("val")
		if val != "-" {
			return val
		} else {
			panic(fmt.Sprintf("No default value defined for %s on %s. User specified value is required.", fieldName, ot.String()))
		}
	} else {
		panic(fmt.Sprintf("Missing %s for %s", fieldName, ot.String()))
	}
}

func normalizeNamespace(ctx context.Context, ns string) string {
	//TODO: compile once
	if res, _ := regexp.MatchString(`\)$`, ns); res {
		return ns
	} else {
		return ns + "()"
	}
}

// Decode the struct from bytes given an encoding
// For now only JSON is supported
func decodeInterface(ctx context.Context, encoding string, b []byte, o interface{}) {
	switch encoding {
	case "json":
		decodeJsonInterface(ctx, b, o)
	default:
		panic(fmt.Sprintf("Unknown encoding %s", encoding))
	}
}

// Decode an array of bytes representing a json string into interface
// Panics if there is an error decoding the JSON data
func decodeJsonInterface(ctx context.Context, b []byte, o interface{}) {
	decoder := json.NewDecoder(bytes.NewReader(b))
	for {
		if err := decoder.Decode(&o); err == io.EOF {
			break
		} else if err != nil {
			panic(err)
		}
	}
}

// Like decodeJsonInterface but returns the error instead of panicking, so an
// empty/scalar element (e.g. an unset management_network) can't crash the daemon.
func decodeJsonInterfaceErr(ctx context.Context, b []byte, o interface{}) error {
	return json.Unmarshal(b, o)
}

func listPfconfigFields(ctx context.Context, t reflect.Type, previousFields []string) []string {
	for i := 0; i < t.NumField(); i++ {
		f := t.Field(i)
		if f.Type.Kind() == reflect.Struct {
			previousFields = append(previousFields, listPfconfigFields(ctx, f.Type, previousFields)...)
		} else if isNamespaceConfiguration.MatchString(f.Name) && !isNotNamespaceConfiguration.MatchString(f.Name) {
			previousFields = append(previousFields, f.Name)
		}
	}
	fieldsMap := map[string]bool{}
	for _, v := range previousFields {
		fieldsMap[v] = true
	}
	fields := make([]string, len(fieldsMap), len(fieldsMap))
	i := 0
	for v, _ := range fieldsMap {
		fields[i] = v
		i++
	}

	return fields
}

func transferMetadata(ctx context.Context, o1 interface{}, o2 interface{}) {
	var ov1 reflect.Value
	var ov2 reflect.Value

	ov1 = reflect.ValueOf(o1)
	for ov1.Kind() == reflect.Ptr || ov1.Kind() == reflect.Interface {
		ov1 = ov1.Elem()
	}

	ov2 = reflect.ValueOf(o2)
	for ov2.Kind() == reflect.Ptr || ov2.Kind() == reflect.Interface {
		ov2 = ov2.Elem()
	}

	t := ov1.Type()
	fields := listPfconfigFields(ctx, t, []string{})
	for _, field := range fields {
		ov2.FieldByName(field).SetString(metadataFromField(ctx, o1, field))
	}

	o1 = ov1.Interface()
	o2 = ov2.Interface()

}

// Create a pfconfig query given a PfconfigObject
// Will extract the query information from the struct and will create the payload accordingly
// The struct should declare the following fields to be compatible
//
//	PfconfigNS - the pfconfig namespace to use (ex: resource::fqdn)
//	PfconfigMethod - the method to use while calling pfconfig (hash_element is a special case, see below)
//	PfconfigHashNS - the hash element key when using the hash_element method, this attribute has no effect when using any other method
func createQuery(ctx context.Context, o PfconfigObject) Query {
	query := Query{}

	query.basens = metadataFromField(ctx, o, "PfconfigNS")

	if GetClusterSummary(ctx).ClusterEnabled == 1 && metadataFromField(ctx, o, "PfconfigHostnameOverlay") == "yes" && !nsHasOverlayRe.MatchString(query.basens) {
		query.basens = query.basens + "(" + myHostname + ")"
	}

	if GetClusterSummary(ctx).ClusterEnabled == 1 {
		if metadataFromField(ctx, o, "PfconfigClusterNameOverlay") == "yes" && !nsHasOverlayRe.MatchString(query.basens) {
			clusterName := FindClusterName(ctx)
			if clusterName == "" {
				panic("Can't determine cluster name for this host")
			}

			query.basens = query.basens + "(" + clusterName + ")"
		}
	}

	// Make sure the namespace is normalized
	query.basens = normalizeNamespace(ctx, query.basens)

	query.method = metadataFromField(ctx, o, "PfconfigMethod")
	if query.method == "hash_element" {
		query.ns = query.basens + ";" + metadataFromField(ctx, o, "PfconfigHashNS")
	} else {
		query.ns = query.basens
	}
	query.encoding = "json"
	return query
}

func FindClusterName(ctx context.Context) string {
	if myClusterName == "" {
		var res ClusterName
		res.PfconfigHashNS = myHostname
		FetchDecodeSocketCache(ctx, &res)
		myClusterName = res.Element
	}
	return myClusterName
}

// Checks whether the last touch cache that pfconfig reported when the PfconfigObject was loaded
// (set by FetchDecodeSocket) is still the one pfconfig reports now.
// pfconfig touches that value every time a namespace is expired, so any change of it means the
// resource isn't valid anymore. Only the values reported by pfconfig are compared with each
// other, never with our own clock, so this holds when pfconfig runs with a different clock than
// we do (another container, another cluster member) or when a clock steps backwards.
func IsValid(ctx context.Context, o PfconfigObject) bool {
	q := createQuery(ctx, o)
	ns := q.basens

	if globalMeta.getLastTouchCache() == 0 {
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Memory configuration was never loaded. Considering %s as invalid do the initial load.", ns))
		return false
	} else if float64(time.Now().UnixMicro()/1000000)-globalMeta.getReloadedTouchCache() > globalMeta.getPhoneInAtLeast() {
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Memory configuration is more than %d seconds old. Considering %s as invalid do reload it.", int(globalMeta.getPhoneInAtLeast()), ns))
	} else if o.GetLoadedTouchCache() == globalMeta.getLastTouchCache() {
		return true
	}
	log.LoggerWContext(ctx).Debug(fmt.Sprintf("Resource is not valid anymore. Was loaded at %s", o.GetLoadedAt()))
	return false
}

// Stores the last touch cache that a reply from pfconfig carried.
// A reply that carries none decodes as zero, and zero is what IsValid reads as "nothing was ever
// loaded", so storing it would invalidate every resource of the process at once and send all of
// them back to pfconfig. The value we already have is kept instead, which makes the resources
// reload when pfconfig reports a different one, like they do for any expiration.
func updateLastTouchCache(ctx context.Context, lastTouchCache float64, identifier string) bool {
	if lastTouchCache == 0 {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("The reply for %s carried no last touch cache. Keeping the one we have.", identifier))
		return false
	}

	globalMeta.setLastTouchCache(lastTouchCache)
	return true
}

// Fetch and decode from the socket but only if the PfconfigObject is not valid anymore
func FetchDecodeSocketCache(ctx context.Context, o PfconfigObject) (bool, error) {
	query := createQuery(ctx, o)
	ctx = log.AddToLogContext(ctx, "PfconfigObject", query.GetIdentifier())

	// If the resource is still valid and is already loaded
	if IsValid(ctx, o) {
		return false, nil
	}

	err := FetchDecodeSocket(ctx, o)
	return true, err
}

// Fetch the keys of a namespace
func FetchKeys(ctx context.Context, name string) ([]string, error) {
	keys := PfconfigKeys{PfconfigNS: name}
	err := FetchDecodeSocket(ctx, &keys)
	if err != nil {
		return nil, err
	}

	return keys.Response.Keys, nil
}

// Fetch and decode a namespace from pfconfig given a pfconfig compatible struct
// This will fetch the json representation from pfconfig and decode it into o
// o must be a pointer to the struct as this should be used by reference
func FetchDecodeSocket(ctx context.Context, o PfconfigObject) error {
	ptrT := reflect.TypeOf(o)
	new := reflect.New(ptrT.Elem())
	newo := new.Interface().(PfconfigObject)

	transferMetadata(ctx, &o, &newo)

	// Decode into a fresh object. A failed refresh must preserve the caller's
	// previous configuration and its validity metadata.
	destination := o
	o = newo

	query := createQuery(ctx, o)

	jsonResponse := FetchSocket(ctx, query.GetPayload())

	var lastTouchCache float64

	if query.method == "keys" {
		if cs, ok := o.(PfconfigKeysInt); ok {
			if err := decodeJsonInterfaceErr(ctx, jsonResponse, cs.GetResponse()); err != nil {
				return fmt.Errorf("could not decode keys for %s: %w", query.GetIdentifier(), err)
			}
			cs.SetKeysFromResponse()
			lastTouchCache = o.GetLastTouchCache()
		} else {
			panic("Wrong struct type for keys. Required PfconfigKeysInt")
		}
	} else if metadataFromField(ctx, o, "PfconfigArray") == "yes" || metadataFromField(ctx, o, "PfconfigDecodeInElement") == "yes" {
		if err := decodeJsonInterfaceErr(ctx, jsonResponse, o); err != nil {
			return fmt.Errorf("could not decode response for %s: %w", query.GetIdentifier(), err)
		}
		lastTouchCache = o.GetLastTouchCache()
	} else {
		receiver := &PfconfigElementResponse{}
		if err := decodeJsonInterfaceErr(ctx, jsonResponse, receiver); err != nil {
			return fmt.Errorf("could not decode response for %s: %w", query.GetIdentifier(), err)
		}
		lastTouchCache = receiver.LastTouchCache

		if receiver.Element != nil {
			b, _ := receiver.Element.MarshalJSON()
			if err := decodeJsonInterfaceErr(ctx, b, o); err != nil {
				return fmt.Errorf("could not decode element in response for %s: %w. Response was: %s", query.GetIdentifier(), err, jsonResponse)
			}
		} else {
			return fmt.Errorf("element in response for %s was invalid. Response was: %s", query.GetIdentifier(), jsonResponse)
		}
	}

	// Only a reply we could decode updates the last touch cache, so a failed fetch above leaves
	// the resources that are loaded alone instead of sending all of them back to pfconfig
	loadedTouchCache := lastTouchCache
	if !updateLastTouchCache(ctx, lastTouchCache, query.GetIdentifier()) {
		// The reply carried none, so the global is the only value we can stamp this one with
		loadedTouchCache = globalMeta.getLastTouchCache()
	}

	globalMeta.setReloadedTouchCache(float64(time.Now().UnixMicro() / 1000000))
	o.SetLoadedAt(time.Now())
	// Stamping from the global instead would let a fetch that overlaps this one move it, and this
	// resource would then carry a touch cache that its own reply was not built with
	o.SetLoadedTouchCache(loadedTouchCache)
	reflect.ValueOf(destination).Elem().Set(reflect.ValueOf(o).Elem())

	return nil
}

func GetClusterSummary(ctx context.Context) ClusterSummary {
	if clusterSummary != nil {
		return *clusterSummary
	}

	query := Query{}
	query.ns = "resource::cluster_summary"
	query.method = "element"
	query.encoding = "json"

	// Will make it try for roughly 1 minute
	for i := 0; i < 60; i++ {
		clusterSummary = &ClusterSummary{}

		jsonResponse := FetchSocket(ctx, query.GetPayload())
		receiver := &PfconfigElementResponse{}
		decodeInterface(ctx, query.encoding, jsonResponse, receiver)
		if receiver.Element != nil {
			b, _ := receiver.Element.MarshalJSON()
			decodeInterface(ctx, query.encoding, b, clusterSummary)
			break
		} else {
			log.LoggerWContext(ctx).Error("Unable to obtain ClusterSummary, will try again")
			time.Sleep(1 * time.Second)
		}
	}

	return *clusterSummary
}

func RefreshLastTouchCache(ctx context.Context) {
	fqdn := &FQDN{}
	FetchDecodeSocket(ctx, fqdn)
}
