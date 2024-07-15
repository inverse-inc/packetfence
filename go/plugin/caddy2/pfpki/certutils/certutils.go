package certutils

import (
	"bytes"
	"crypto"
	"crypto/dsa"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"math/big"
	mathrand "math/rand"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"golang.org/x/crypto/ssh"
)

// DSAKeyFormat is the format of a DSA key
type DSAKeyFormat struct {
	Version       int
	P, Q, G, Y, X *big.Int
}

// PRNG pseudorandom number generator
var PRNG io.Reader = rand.Reader

// Supported key format
const (
	KEY_UNSUPPORTED types.Type = iota - 1
	KEY_ECDSA
	KEY_RSA
	KEY_DSA
)

const (
	rsaPrivateKeyPEMBlockType = "RSA PRIVATE KEY"
	certificatePEMBlockType   = "CERTIFICATE"
)

func Extkeyusage(ExtendedKeyUsage []string) []x509.ExtKeyUsage {

	// Set up extra key uses for certificate
	extKeyUsage := make([]x509.ExtKeyUsage, 0)
	for _, use := range ExtendedKeyUsage {
		if use != "" {
			v, _ := strconv.Atoi(use)
			extKeyUsage = append(extKeyUsage, x509.ExtKeyUsage(v))
		}
	}
	return extKeyUsage
}

func Keyusage(KeyUsage []string) int {
	keyUsage := 0
	for _, use := range KeyUsage {
		v, _ := strconv.Atoi(use)
		keyUsage = keyUsage | v
	}
	return keyUsage
}

// GenerateKey function generate the public/private key based on the type and the size
func GenerateKey(keytype types.Type, size int) (keyOut *bytes.Buffer, pub crypto.PublicKey, key crypto.PrivateKey, err error) {

	keyOut = new(bytes.Buffer)

	switch keytype {
	case KEY_RSA:
		if size < 2048 {
			return nil, nil, nil, errors.New("invalid private key size, should be at least 2048")
		}
		var rsakey *rsa.PrivateKey
		rsakey, err = rsa.GenerateKey(PRNG, size)

		if err != nil {
			return nil, nil, nil, err
		}
		key = rsakey
		pub = &key.(*rsa.PrivateKey).PublicKey
		// Private key
		pem.Encode(keyOut, &pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key.(*rsa.PrivateKey))})
	case KEY_ECDSA:
		var eckey *ecdsa.PrivateKey
		switch size {
		case 256:
			eckey, err = ecdsa.GenerateKey(elliptic.P256(), PRNG)
			if err != nil {
				return nil, nil, nil, err
			}
		case 384:
			eckey, err = ecdsa.GenerateKey(elliptic.P384(), PRNG)
			if err != nil {
				return nil, nil, nil, err
			}
		case 521:
			eckey, err = ecdsa.GenerateKey(elliptic.P521(), PRNG)
			if err != nil {
				return nil, nil, nil, err
			}
		default:
			return nil, nil, nil, errors.New("invalid private key size, should be 256 or 384 or 521")
		}
		key = eckey
		pub = &key.(*ecdsa.PrivateKey).PublicKey
		bytes, _ := x509.MarshalECPrivateKey(key.(*ecdsa.PrivateKey))
		pem.Encode(keyOut, &pem.Block{Type: "EC PRIVATE KEY", Bytes: bytes})
	case KEY_DSA:
		var sizes dsa.ParameterSizes
		switch size {
		case 1024:
			sizes = dsa.L1024N160
		case 2048:
			sizes = dsa.L2048N256
		case 3072:
			sizes = dsa.L3072N256
		default:
			return nil, nil, nil, errors.New("invalid private key size, should be 1024 or 2048 or 3072")
		}

		params := dsa.Parameters{}
		err = dsa.GenerateParameters(&params, rand.Reader, sizes)
		if err != nil {
			return nil, nil, nil, err
		}

		dsakey := &dsa.PrivateKey{
			PublicKey: dsa.PublicKey{
				Parameters: params,
			},
		}
		err = dsa.GenerateKey(dsakey, rand.Reader)
		if err != nil {
			return nil, nil, nil, err
		}
		key = dsakey
		pub = &key.(*dsa.PrivateKey).PublicKey
		val := DSAKeyFormat{
			P: key.(*dsa.PrivateKey).P, Q: key.(*dsa.PrivateKey).Q, G: key.(*dsa.PrivateKey).G,
			Y: key.(*dsa.PrivateKey).Y, X: key.(*dsa.PrivateKey).X,
		}
		bytes, _ := asn1.Marshal(val)
		pem.Encode(keyOut, &pem.Block{Type: "DSA PRIVATE KEY", Bytes: bytes})
	}

	return keyOut, pub, key, nil
}

func CalculateSKID(pubKey crypto.PublicKey) ([]byte, error) {
	spkiASN1, err := x509.MarshalPKIXPublicKey(pubKey)
	if err != nil {
		return nil, err
	}

	var spki struct {
		Algorithm        pkix.AlgorithmIdentifier
		SubjectPublicKey asn1.BitString
	}
	_, err = asn1.Unmarshal(spkiASN1, &spki)
	if err != nil {
		return nil, err
	}
	skid := sha1.Sum(spki.SubjectPublicKey.Bytes)
	return skid[:], nil
}

func GeneratePassword() string {
	r := mathrand.New(mathrand.NewSource(time.Now().UnixNano()))
	chars := []rune("ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
		"abcdefghijklmnopqrstuvwxyz" +
		"0123456789")
	length := 8
	var b strings.Builder
	for i := 0; i < length; i++ {
		b.WriteRune(chars[r.Intn(len(chars))])
	}
	return b.String()
}

func ExportRsaPrivateKeyAsPemStr(privkey *rsa.PrivateKey) string {
	privkey_bytes := x509.MarshalPKCS1PrivateKey(privkey)
	privkey_pem := pem.EncodeToMemory(
		&pem.Block{
			Type:  "RSA PRIVATE KEY",
			Bytes: privkey_bytes,
		},
	)
	return string(privkey_pem)
}

func ParseRsaPrivateKeyFromPemStr(privPEM string) (interface{}, error) {
	block, _ := pem.Decode([]byte(privPEM))
	if block == nil {
		return nil, errors.New("failed to parse PEM block containing the key")
	}

	priv, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}

	return priv, nil
}

func ExportRsaPublicKeyAsPemStr(pubkey *rsa.PublicKey) (string, error) {
	pubkey_bytes, err := x509.MarshalPKIXPublicKey(pubkey)
	if err != nil {
		return "", err
	}
	pubkey_pem := pem.EncodeToMemory(
		&pem.Block{
			Type:  "RSA PUBLIC KEY",
			Bytes: pubkey_bytes,
		},
	)

	return string(pubkey_pem), nil
}

func ParseRsaPublicKeyFromPemStr(pubPEM string) (*rsa.PublicKey, error) {
	block, _ := pem.Decode([]byte(pubPEM))

	if block == nil {
		return nil, errors.New("failed to parse PEM block containing the key")
	}

	pub, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return nil, err
	}

	switch pub := pub.(type) {
	case *rsa.PublicKey:
		return pub, nil
	default:
		break // fall through
	}
	return nil, errors.New("Key type is not RSA")
}

// parses a pem encoded x509 certificate
func ParseCertFile(pubPEM string) (*x509.Certificate, error) {
	block, _ := pem.Decode([]byte(pubPEM))
	if block == nil {
		return nil, errors.New("failed to parse PEM block containing the key")
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return nil, err
	}
	return cert, nil
}

// parses a PEM encoded PKCS8 private key (RSA only)
func ParseKeyFile(filename string) (interface{}, error) {
	kt, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	block, _ := pem.Decode(kt)
	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	return key, nil
}

// load an encrypted private key from disk
func LoadKey(data []byte, password []byte) (*rsa.PrivateKey, error) {
	pemBlock, _ := pem.Decode(data)
	if pemBlock == nil {
		return nil, errors.New("PEM decode failed")
	}
	if pemBlock.Type != rsaPrivateKeyPEMBlockType {
		return nil, errors.New("unmatched type or headers")
	}

	b, err := x509.DecryptPEMBlock(pemBlock, password)
	if err != nil {
		return x509.ParsePKCS1PrivateKey(pemBlock.Bytes)
	}

	return x509.ParsePKCS1PrivateKey(b)
}

func LoadCert(data []byte) (*x509.Certificate, error) {
	pemBlock, _ := pem.Decode(data)
	if pemBlock == nil {
		return nil, errors.New("PEM decode failed")
	}
	if pemBlock.Type != certificatePEMBlockType {
		return nil, errors.New("unmatched type or headers")
	}

	return x509.ParseCertificate(pemBlock.Bytes)
}

func PemCert(derBytes []byte) []byte {
	pemBlock := &pem.Block{
		Type:    certificatePEMBlockType,
		Headers: nil,
		Bytes:   derBytes,
	}
	out := pem.EncodeToMemory(pemBlock)
	return out
}

var oid = map[string]string{
	"2.5.4.3":                    "CN",
	"2.5.4.4":                    "SN",
	"2.5.4.5":                    "serialNumber",
	"2.5.4.6":                    "C",
	"2.5.4.7":                    "L",
	"2.5.4.8":                    "ST",
	"2.5.4.9":                    "streetAddress",
	"2.5.4.10":                   "O",
	"2.5.4.11":                   "OU",
	"2.5.4.12":                   "title",
	"2.5.4.17":                   "postalCode",
	"2.5.4.42":                   "GN",
	"2.5.4.43":                   "initials",
	"2.5.4.44":                   "generationQualifier",
	"2.5.4.46":                   "dnQualifier",
	"2.5.4.65":                   "pseudonym",
	"0.9.2342.19200300.100.1.25": "DC",
	"1.2.840.113549.1.9.1":       "emailAddress",
	"0.9.2342.19200300.100.1.1":  "userid",
}

func GetDNFromCert(namespace pkix.Name) map[string]string {

	attributeMap := make(map[string]string)

	for _, v := range oid {
		attributeMap[v] = ""
	}

	for _, s := range namespace.ToRDNSequence() {
		for _, i := range s {
			if v, ok := i.Value.(string); ok {
				if name, ok := oid[i.Type.String()]; ok {
					attributeMap[name] = v
				}
			}

		}
	}
	return attributeMap
}

func ThumbprintSHA1(cert *x509.Certificate) string {
	sum := sha1.Sum(cert.Raw)
	hex := make([]string, len(sum))
	for i, b := range sum {
		hex[i] = fmt.Sprintf("%02X", b)
	}
	return strings.Join(hex, ":")
}

func MakeSubject(Subject pkix.Name, attributes map[string]string) pkix.Name {

	for k, v := range attributes {
		switch k {
		case "Organization":
			if len(v) > 0 {
				Subject.Organization = []string{v}
			}
		case "OrganizationalUnit":
			if len(v) > 0 {
				Subject.OrganizationalUnit = []string{v}
			}
		case "Country":
			if len(v) > 0 {
				Subject.Country = []string{v}
			}
		case "State":
			if len(v) > 0 {
				Subject.Province = []string{v}
			}
		case "Locality":
			if len(v) > 0 {
				Subject.Locality = []string{v}
			}
		case "StreetAddress":
			if len(v) > 0 {
				Subject.StreetAddress = []string{v}
			}
		case "PostalCode":
			if len(v) > 0 {
				Subject.PostalCode = []string{v}
			}
		}
	}
	return Subject
}

func ForEachSAN(extension []byte, attributes map[string]string) (pkix.Extension, error) {
	// RFC 5280, 4.2.1.6

	// SubjectAltName ::= GeneralNames
	//
	// GeneralNames ::= SEQUENCE SIZE (1..MAX) OF GeneralName
	//
	// GeneralName ::= CHOICE {
	//      otherName                       [0]     OtherName,
	//      rfc822Name                      [1]     IA5String,
	//      dNSName                         [2]     IA5String,
	//      x400Address                     [3]     ORAddress,
	//      directoryName                   [4]     Name,
	//      ediPartyName                    [5]     EDIPartyName,
	//      uniformResourceIdentifier       [6]     IA5String,
	//      iPAddress                       [7]     OCTET STRING,
	//      registeredID                    [8]     OBJECT IDENTIFIER }

	var seq asn1.RawValue

	extSubjectAltName := pkix.Extension{
		Id:       asn1.ObjectIdentifier{2, 5, 29, 17},
		Critical: false,
		Value:    extension,
	}

	rest, err := asn1.Unmarshal(extension, &seq)
	if err != nil {
		return extSubjectAltName, err
	} else if len(rest) != 0 {
		return extSubjectAltName, errors.New("x509: trailing data after X.509 extension")
	}
	if !seq.IsCompound || seq.Tag != 16 || seq.Class != 0 {
		return extSubjectAltName, asn1.StructuralError{Msg: "bad SAN sequence"}
	}

	rest = seq.Bytes
	var rawValues []asn1.RawValue

	found := false
	for len(rest) > 0 {
		var v asn1.RawValue
		rest, err = asn1.Unmarshal(rest, &v)
		if err != nil {
			return extSubjectAltName, err
		}
		if v.Tag == 1 {
			found = true
		}
		rawValues = append(rawValues, v)
	}

	if found {
		return extSubjectAltName, nil
	} else {
		rawValues = append(rawValues, asn1.RawValue{
			Class:      2,
			IsCompound: false,
			Tag:        1,
			Bytes:      []byte(attributes["Mail"]),
		})
		RawValue, _ := asn1.Marshal(rawValues)
		extSubjectAltName = pkix.Extension{
			Id:       asn1.ObjectIdentifier{2, 5, 29, 17},
			Critical: false,
			Value:    RawValue,
		}
		return extSubjectAltName, nil
	}
}

func CertName(crt *x509.Certificate) string {
	if crt.Subject.CommonName != "" {
		return crt.Subject.CommonName
	}
	return string(crt.Signature)
}

func ReturnDSAPrivateKey(key *dsa.PrivateKey) (*bytes.Buffer, []byte, crypto.PublicKey, crypto.PrivateKey, error) {
	var keyOut *bytes.Buffer
	var pub crypto.PublicKey
	var privkey crypto.PrivateKey
	privkey = key
	keyOut = new(bytes.Buffer)
	pub = &key.PublicKey
	skid, err := CalculateSKID(pub)
	if err != nil {
		return keyOut, skid, pub, privkey, err
	}
	val := DSAKeyFormat{
		P: key.P, Q: key.Q, G: key.G,
		Y: key.Y, X: key.X,
	}
	bytes, _ := asn1.Marshal(val)
	pem.Encode(keyOut, &pem.Block{Type: "DSA PRIVATE KEY", Bytes: bytes})
	return keyOut, skid, pub, privkey, err
}

func ReturnECDSAPrivateKey(key *ecdsa.PrivateKey) (*bytes.Buffer, []byte, crypto.PublicKey, crypto.PrivateKey, error) {
	var keyOut *bytes.Buffer
	var pub crypto.PublicKey
	var privkey crypto.PrivateKey
	privkey = key
	keyOut = new(bytes.Buffer)
	pub = &key.PublicKey
	skid, err := CalculateSKID(pub)
	if err != nil {
		return keyOut, skid, pub, privkey, err
	}
	bytes, _ := x509.MarshalECPrivateKey(key)
	pem.Encode(keyOut, &pem.Block{Type: "EC PRIVATE KEY", Bytes: bytes})
	return keyOut, skid, pub, privkey, err
}

func ReturnRSAPrivateKey(key *rsa.PrivateKey) (*bytes.Buffer, []byte, crypto.PublicKey, crypto.PrivateKey, error) {
	var keyOut *bytes.Buffer
	var pub crypto.PublicKey
	var privkey crypto.PrivateKey
	privkey = key
	keyOut = new(bytes.Buffer)
	pub = &key.PublicKey

	skid, err := CalculateSKID(pub)
	if err != nil {
		return keyOut, skid, pub, privkey, err
	}
	pem.Encode(keyOut, &pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)})
	return keyOut, skid, pub, privkey, err
}

func ReturnPrivateKey(key []byte) (*bytes.Buffer, []byte, crypto.PublicKey, crypto.PrivateKey, error) {
	var keyOut *bytes.Buffer
	keyOut = new(bytes.Buffer)
	pkey, err := x509.ParsePKCS8PrivateKey(key)
	if err != nil {
		return keyOut, nil, nil, nil, err
	}
	switch pkey.(type) {
	case *ecdsa.PrivateKey:
		return ReturnECDSAPrivateKey(pkey.(*ecdsa.PrivateKey))
	case *dsa.PrivateKey:
		return ReturnDSAPrivateKey(pkey.(*dsa.PrivateKey))
	case *rsa.PrivateKey:
		return ReturnRSAPrivateKey(pkey.(*rsa.PrivateKey))
	default:
		return keyOut, nil, nil, nil, err
	}

}

func ExtractPrivateKey(KeyType *types.Type, block *pem.Block, Information *types.Info) (*bytes.Buffer, []byte, crypto.PublicKey, crypto.PrivateKey, types.Info, error) {
	var skid []byte
	var keyOut *bytes.Buffer
	keyOut = new(bytes.Buffer)
	var key crypto.PrivateKey
	var pub crypto.PublicKey
	switch *KeyType {
	case KEY_RSA:
		keyRSA, err := x509.ParsePKCS1PrivateKey(block.Bytes)
		if err != nil {
			keyOut, skid, pub, key, err = ReturnPrivateKey(block.Bytes)
			if err != nil {
				Information.Error = err.Error()
				return keyOut, skid, pub, key, *Information, err
			}
		} else {
			keyOut, skid, pub, key, err = ReturnRSAPrivateKey(keyRSA)
			if err != nil {
				Information.Error = err.Error()
				return keyOut, skid, pub, key, *Information, err
			}
		}
	case KEY_ECDSA:
		KeyECDSA, err := x509.ParseECPrivateKey(block.Bytes)
		if err != nil {
			keyOut, skid, pub, key, err = ReturnPrivateKey(block.Bytes)
			if err != nil {
				Information.Error = err.Error()
				return keyOut, skid, pub, key, *Information, err
			}
		} else {
			keyOut, skid, pub, key, err = ReturnECDSAPrivateKey(KeyECDSA)
			if err != nil {
				Information.Error = err.Error()
				return keyOut, skid, pub, key, *Information, err
			}
		}
	case KEY_DSA:
		KeyDSA, err := ssh.ParseDSAPrivateKey(block.Bytes)
		if err != nil {
			keyOut, skid, pub, key, err = ReturnPrivateKey(block.Bytes)
			if err != nil {
				Information.Error = err.Error()
				return keyOut, skid, pub, key, *Information, err
			}
		} else {
			keyOut, skid, pub, key, err = ReturnDSAPrivateKey(KeyDSA)
			if err != nil {
				Information.Error = err.Error()
				return keyOut, skid, pub, key, *Information, err
			}
		}
	}
	return keyOut, skid, pub, key, *Information, nil
}
