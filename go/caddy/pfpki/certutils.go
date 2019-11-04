package pfpki

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
	"io"
	"math/big"
	"strconv"
)

// Type of key
type Type int

// DSAKeyFormat is the format of a DSA key
type DSAKeyFormat struct {
	Version       int
	P, Q, G, Y, X *big.Int
}

// PRNG pseudorandom number generator
var PRNG io.Reader = rand.Reader

// Supported key format
const (
	KEY_UNSUPPORTED Type = iota - 1
	KEY_ECDSA
	KEY_RSA
	KEY_DSA
)

func extkeyusage(ExtendedKeyUsage []string) []x509.ExtKeyUsage {
	// Set up extra key uses for certificate
	extKeyUsage := make([]x509.ExtKeyUsage, 0)
	for _, use := range ExtendedKeyUsage {
		v, _ := strconv.Atoi(use)
		extKeyUsage = append(extKeyUsage, x509.ExtKeyUsage(v))
	}

	return extKeyUsage
}

func keyusage(KeyUsage []string) int {
	keyUsage := 0
	for _, use := range KeyUsage {
		v, _ := strconv.Atoi(use)
		keyUsage = keyUsage | v
	}
	return keyUsage
}

// GenerateKey function generate the public/private key based on the type and the size
func GenerateKey(keytype Type, size int) (keyOut *bytes.Buffer, pub crypto.PublicKey, key crypto.PrivateKey, err error) {

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

func calculateSKID(pubKey crypto.PublicKey) ([]byte, error) {
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
