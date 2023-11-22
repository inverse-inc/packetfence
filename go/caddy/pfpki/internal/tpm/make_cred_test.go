/*
Copyright (c) 2020 GMO GlobalSign, Inc.

Licensed under the MIT License (the "License"); you may not use this file except
in compliance with the License. You may obtain a copy of the License at

https://opensource.org/licenses/MIT

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package tpm_test

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/rsa"
	"errors"
	"testing"

	"github.com/google/go-tpm/tpm2"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/internal/tpm"
)

func TestMakeAndExtractCredential(t *testing.T) {
	t.Parallel()

	var testcases = []struct {
		name    string
		cred    []byte
		ek      interface{}
		ak      interface{}
		keyBits uint16
	}{
		{
			name:    "RSA/AES128",
			cred:    []byte(`Hello, world!`),
			ek:      mustGenerateRSAKey(t),
			ak:      mustGenerateRSAKey(t),
			keyBits: 128,
		},
		{
			name:    "RSA/AES192",
			cred:    []byte(`Leave all hope, ye that enter`),
			ek:      mustGenerateRSAKey(t),
			ak:      mustGenerateRSAKey(t),
			keyBits: 192,
		},
		{
			name:    "RSA/AES256",
			cred:    []byte(`"Commonplace, Watson."`),
			ek:      mustGenerateRSAKey(t),
			ak:      mustGenerateRSAKey(t),
			keyBits: 256,
		},
	}

	for _, tc := range testcases {
		var tc = tc

		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			ekPub := storagePublicAreaFromKey(t, tc.ek, tc.keyBits)
			akPub := storagePublicAreaFromKey(t, tc.ak, tc.keyBits)

			// Make credential.
			blob, encSeed, err := tpm.MakeCredential(tc.cred, ekPub, akPub)
			if err != nil {
				t.Fatalf("couldn't make credential: %v", err)
			}

			// Extract credential, including some error cases for a sanity
			// check.
			var subcases = []struct {
				name    string
				blob    []byte
				encSeed []byte
				err     error
			}{
				{
					name:    "OK",
					blob:    blob,
					encSeed: encSeed,
				},
				{
					name:    "BadSeed",
					blob:    blob,
					encSeed: invertByte(encSeed, 4),
					err:     errors.New("decryption error"),
				},
				{
					name:    "BadHMACSize",
					blob:    invertByte(blob, 1),
					encSeed: encSeed,
					err:     errors.New("incorrect size"),
				},
				{
					name:    "BadHMAC",
					blob:    invertByte(blob, 4),
					encSeed: encSeed,
					err:     errors.New("invalid HMAC"),
				},
				{
					name:    "BadCredential",
					blob:    invertByte(blob, 36),
					encSeed: encSeed,
					err:     errors.New("invalid HMAC due to altered credential"),
				},
			}

			for _, sc := range subcases {
				var sc = sc

				t.Run(sc.name, func(t *testing.T) {
					t.Parallel()

					// Extract credential.
					got, err := tpm.ExtractCredential(tc.ek, sc.blob, sc.encSeed, ekPub, akPub)
					if (err == nil) != (sc.err == nil) {
						t.Fatalf("got error %v, want %v", err, sc.err)
					}

					// Check activated credential is as expected.
					if err == nil && !bytes.Equal(got, tc.cred) {
						t.Fatalf("got %q, want %q", string(got), string(tc.cred))
					}
				})
			}
		})
	}
}

func mustGenerateRSAKey(t *testing.T) interface{} {
	t.Helper()

	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("failed to generate RSA key: %v", err)
	}

	return key
}

func storagePublicAreaFromKey(t *testing.T, key interface{}, keyBits uint16) []byte {
	t.Helper()

	pub := tpm2.Public{
		NameAlg:    tpm2.AlgSHA256,
		Attributes: tpm2.FlagStorageDefault,
	}

	switch k := key.(type) {
	case *rsa.PrivateKey:
		pub.Type = tpm2.AlgRSA
		pub.RSAParameters = &tpm2.RSAParams{
			Symmetric: &tpm2.SymScheme{
				Alg:     tpm2.AlgAES,
				KeyBits: keyBits,
				Mode:    tpm2.AlgCFB,
			},
			KeyBits:     2048,
			ExponentRaw: uint32(k.E),
			ModulusRaw:  k.PublicKey.N.Bytes(),
		}

	case *ecdsa.PrivateKey:
		pub.Type = tpm2.AlgRSA
		pub.ECCParameters = &tpm2.ECCParams{
			Symmetric: &tpm2.SymScheme{
				Alg:     tpm2.AlgAES,
				KeyBits: keyBits,
				Mode:    tpm2.AlgCFB,
			},
			CurveID: tpm2.CurveNISTP256,
			Point: tpm2.ECPoint{
				XRaw: k.PublicKey.X.Bytes(),
				YRaw: k.PublicKey.Y.Bytes(),
			},
		}

	default:
		t.Fatalf("unexpected private key type: %T", k)
	}

	enc, err := pub.Encode()
	if err != nil {
		t.Fatalf("failed to encode public area: %v", err)
	}

	return enc
}

// invertByte makes a copy of the provided by slice and bitwise negates the
// element at the specified index. The intended use is to invalidate a
// specific byte of an otherwise valid binary blob.
func invertByte(b []byte, index int) []byte {
	r := make([]byte, len(b))
	copy(r, b)
	r[index] = ^r[index]
	return r
}
