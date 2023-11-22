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

package tpm

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdsa"
	"crypto/hmac"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/binary"
	"errors"
	"fmt"
	"hash"
	"io"

	"github.com/google/go-tpm/tpm2"
	"github.com/google/go-tpm/tpmutil"
)

const (
	labelIdentity  = "IDENTITY"
	labelIntegrity = "INTEGRITY"
	labelStorage   = "STORAGE"
	sizeFieldLen   = 2
)

// MakeCredential makes a credential for the object with the public area
// akPublic, to be activated by the object with the public area ekPublic.
// The credential blob and the encrypted seed are returned.
func MakeCredential(cred, ekPublic, akPublic []byte) ([]byte, []byte, error) {
	// Decode endorsement and attestation key public areas.
	ekPub, err := tpm2.DecodePublic(ekPublic)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to decode endorsement key public area: %w", err)
	}

	akPub, err := tpm2.DecodePublic(akPublic)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to decode attestation key public area: %w", err)
	}

	// Generate seed and EK-encrypted seed.
	seed, encSeed, err := generateSeed(ekPub)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to generate seed: %w", err)
	}

	// Generate credential blob.
	blob, err := generateCredentialBlob(ekPub, akPub, cred, seed)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to generate credential blob: %w", err)
	}

	return blob, encSeed, nil
}

// ExtractCredential extracts a credential from a credential blob and encrypted
// seed created by MakeCredential. This function is primarily for testing and
// demonstration purposes, since in practice the private key corresponding to
// the TPM endorsement key public area will not be available.
func ExtractCredential(key interface{}, blob, encSeed, ekPublic, akPublic []byte) ([]byte, error) {
	// Decode endorsement and attestation key public areas.
	ekPub, err := tpm2.DecodePublic(ekPublic)
	if err != nil {
		return nil, fmt.Errorf("failed to decode endorsement key public area: %w", err)
	}

	akPub, err := tpm2.DecodePublic(akPublic)
	if err != nil {
		return nil, fmt.Errorf("failed to decode attestation key public area: %w", err)
	}

	// Decrypt seed.
	seed, err := decryptSeed(key, ekPub, encSeed)
	if err != nil {
		return nil, fmt.Errorf("failed to decrypt seed: %w", err)
	}

	// Extract credential.
	cred, err := decryptCredentialBlob(blob, ekPub, akPub, seed)
	if err != nil {
		return nil, fmt.Errorf("failed to extract credential: %w", err)
	}

	return cred, nil
}

// generateSeed generates a seed value and encrypts it using the public key
// in the specified public area per TPM Library specification Section 24.
func generateSeed(ekPub tpm2.Public) ([]byte, []byte, error) {
	// Extract the name algorithm from the public area.
	newHash, err := nameAlgHashFromPublic(ekPub)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to determine EK name hash algorithm: %w", err)
	}

	// Generate a random seed value. Per TPM Library spec Appendix B.10.3, for
	// RSA keys the seed size will be the size of a digest produced by the OAEP
	// hash algorithm of the endorsement key, and per TPM Library spec Appendix
	// C.6.1, for ECC keys the seed size will be the size of a digest produced
	// by the name algorithm for the endorsement key. In both cases, this
	// equates to the size of the digest of the EK's name algorithm, so we
	// generate a random seed of that size.
	h := newHash()
	seedSize := h.Size()
	seed := make([]byte, seedSize)
	if n, err := io.ReadFull(rand.Reader, seed); err != nil {
		return nil, nil, fmt.Errorf("failed to generate random bytes: %w", err)
	} else if n != seedSize {
		return nil, nil, fmt.Errorf("generated %d random bytes, expected %d", n, seedSize)
	}

	// Encrypt the seed according to the type of the EK public key.
	pubKey, err := ekPub.Key()
	if err != nil {
		return nil, nil, fmt.Errorf("failed to extract EK public key: %w", err)
	}

	var encSeed []byte

	switch k := pubKey.(type) {
	case *rsa.PublicKey:

		// Per TPM Library spec Appendix B.10.4, the seed value will be OAEP
		// encrypted to the EK public key using "IDENTITY" as the label
		// (including the terminaing null octet per Appendix B.4.)
		encSeed, err = rsa.EncryptOAEP(h, rand.Reader, k, seed, append([]byte(labelIdentity), 0))
		if err != nil {
			return nil, nil, fmt.Errorf("failed to RSA encrypt: %w", err)
		}

	case *ecdsa.PublicKey:

		// Per TPM Library spec Appendix C.6.4, the One-Pass Diffie-Hellman,
		// C(1, 1, ECC CDH) method from SP800-56A shall be used.
		return nil, nil, errors.New("ECC keys not yet supported for seed encryption")

	default:
		return nil, nil, fmt.Errorf("unsupported public key type: %T", k)
	}

	return seed, encSeed, nil
}

// decryptSeed decrypts an encrypted seed created by generateSeed. In practice
// the decryption private key will not be available, so this function is provided
// primarily for testing and verification.
func decryptSeed(key interface{}, ekPub tpm2.Public, encSeed []byte) ([]byte, error) {
	// Extract the name algorithm from the public area.
	h, err := nameAlgHashFromPublic(ekPub)
	if err != nil {
		return nil, err
	}

	// Decrypt the seed based on the type of key. See comments to
	// generateSeed.
	var got []byte

	switch k := key.(type) {
	case *rsa.PrivateKey:
		got, err = rsa.DecryptOAEP(h(), rand.Reader, k, encSeed, append([]byte(labelIdentity), 0))
		if err != nil {
			return nil, fmt.Errorf("failed to RSA decrypt: %w", err)
		}

	case *ecdsa.PrivateKey:
		return nil, errors.New("ECC keys not yet supported for seed decryption")

	default:
		return nil, fmt.Errorf("unsupported public key type: %T", k)
	}

	return got, nil
}

// generateCredentialBlob generates an encrypted credential and HMAC per
// TPM Library spec Section 24.
func generateCredentialBlob(ekPub, akPub tpm2.Public, cred, seed []byte) ([]byte, error) {
	// Compute AK name.
	name, err := computeName(akPub)
	if err != nil {
		return nil, err
	}

	// Extract the name algorithm from the public area.
	newHash, err := nameAlgHashFromPublic(ekPub)
	if err != nil {
		return nil, fmt.Errorf("failed to determine EK name hash algorithm: %w", err)
	}

	// Encrypt credential.
	encIdentity, err := encryptCredential(ekPub, newHash, cred, seed, name)
	if err != nil {
		return nil, fmt.Errorf("failed to encrypt credential value: %w", err)
	}

	// Compute the HMAC key. Per TPM Library spec Section 24.5, the number of
	// bytes in the key should be equal to the size of the digest produced
	// by the hash algorithm used.
	macKey, err := KDFa(newHash, seed, labelIntegrity, nil, newHash().Size())
	if err != nil {
		return nil, fmt.Errorf("failed to derive integrity key: %w", err)
	}

	// Compute the HMAC
	mac := hmac.New(newHash, macKey)
	mac.Write(encIdentity)
	mac.Write(name)
	macSum := mac.Sum(nil)

	// Create and return the credential blob.
	return tpmutil.Pack(tpmutil.U16Bytes(macSum), encIdentity)
}

// decryptCredentialBlob verifies the HMAC and decrypts the credential in a
// credential blob.
func decryptCredentialBlob(blob []byte, ekPub, akPub tpm2.Public, seed []byte) ([]byte, error) {
	// Compute AK name.
	name, err := computeName(akPub)
	if err != nil {
		return nil, err
	}

	// Extract the name algorithm from the public area.
	newHash, err := nameAlgHashFromPublic(ekPub)
	if err != nil {
		return nil, fmt.Errorf("failed to determine EK name hash algorithm: %w", err)
	}

	// Separate HMAC and encrypted identity from credentials blob, first
	// ensuring that the blob is large enough to contain at least one 2-octet
	// size field.
	if len(blob) < 2 {
		return nil, errors.New("incorrect size for credential blob")
	}

	// Decode the leading 2-octet size field of the HMAC and verify that it's
	// appropriate for the hash algorithm.
	hashSize := newHash().Size()
	if gotSize := int(binary.BigEndian.Uint16(blob)); gotSize != hashSize {
		return nil, errors.New("incorrect size for credential blob")
	}

	// Size of the credential blob should be at least the length of the HMAC,
	// plus 2 for the HMAC size field, plus another 2 for the (encrypted)
	// credential size field, plus 1 for a non-empty credential. Since the
	// credential size field is encrypted, we'll have to defer checking it
	// until after we've decrypted the credential.
	if len(blob) < (hashSize + 5) {
		return nil, errors.New("incorrect size for credential blob")
	}

	gotHMAC := blob[2 : hashSize+2]
	encIdentity := blob[hashSize+2:]

	// Verify the HMAC.
	macKey, err := KDFa(newHash, seed, labelIntegrity, nil, hashSize)
	if err != nil {
		return nil, fmt.Errorf("failed to derive integrity key: %w", err)
	}

	mac := hmac.New(newHash, macKey)
	mac.Write(encIdentity)
	mac.Write(name)

	if !bytes.Equal(gotHMAC, mac.Sum(nil)) {
		return nil, errors.New("failed to verify HMAC")
	}

	// Decrypt credential.
	cred, err := decryptCredential(encIdentity, ekPub, newHash, seed, name)
	if err != nil {
		return nil, fmt.Errorf("failed to decrypt credential: %w", err)
	}

	return cred, nil
}

// encryptCredential encrypts a credential using the appropriate symmetric
// algorithm specified in a public area.
func encryptCredential(pub tpm2.Public, h func() hash.Hash, cred, seed, name []byte) ([]byte, error) {
	// Create an appropriate symmetric cipher.
	cphr, err := cipherFromPublic(pub, h, seed, name)
	if err != nil {
		return nil, err
	}

	// Prepend a 2-octet size field to the credential prior to encryption.
	plain, err := tpmutil.Pack(tpmutil.U16Bytes(cred))
	if err != nil {
		return nil, err
	}

	// Encrypt and return. Per TPM Library spec Part 1 24.4, the encryption of the
	// credential uses the symmetric algorithm specified by the EK in CFB
	// mode with a zero IV.
	enc := make([]byte, len(plain))
	cipher.NewCFBEncrypter(cphr, make([]byte, cphr.BlockSize())).XORKeyStream(enc, plain)

	return enc, nil
}

// decryptCredential decrypts a credential using the appropriate symmetric
// algorithm specified in a public area.
func decryptCredential(encIdentity []byte, ekPub tpm2.Public, h func() hash.Hash, seed, name []byte) ([]byte, error) {
	// Create an appropriate symmetric cipher.
	cphr, err := cipherFromPublic(ekPub, h, seed, name)
	if err != nil {
		return nil, err
	}

	// Decrypt. Per TPM Library spec Part 1 24.4, the encryption of the credential
	// uses the symmetric algorithm specified by the EK in CFB mode with a
	// zero IV.
	dec := make([]byte, len(encIdentity))
	cipher.NewCFBDecrypter(cphr, make([]byte, cphr.BlockSize())).XORKeyStream(dec, encIdentity)

	// Verify leading 2-octet size field, then strip it from the returned
	// credential.
	if int(binary.BigEndian.Uint16(dec)) != len(encIdentity)-2 {
		return nil, errors.New("incorrect size for encIdentity")
	}

	return dec[2:], nil
}

// cipherFromPublic returns a block cipher appropriate for a given storage key.
func cipherFromPublic(pub tpm2.Public, h func() hash.Hash, seed, name []byte) (cipher.Block, error) {
	// Extract symmetric encryption scheme from public area.
	var sym *tpm2.SymScheme

	switch {
	case pub.RSAParameters != nil && pub.RSAParameters.Symmetric != nil:
		sym = pub.RSAParameters.Symmetric

	case pub.ECCParameters != nil && pub.ECCParameters.Symmetric != nil:
		sym = pub.ECCParameters.Symmetric

	default:
		return nil, fmt.Errorf("failed to identify symmetric algorithm")
	}

	// Generate symmetric key and create block cipher.
	var cphr cipher.Block

	switch sym.Alg {
	case tpm2.AlgAES:
		symKey, err := KDFa(h, seed, labelStorage, name, int(sym.KeyBits/8))
		if err != nil {
			return nil, fmt.Errorf("failed to derive storage key: %w", err)
		}

		cphr, err = aes.NewCipher(symKey)
		if err != nil {
			return nil, fmt.Errorf("couldn't create new AES cipher: %w", err)
		}

	default:
		return nil, fmt.Errorf("unsupported symmetric algorithm: %d", sym.Alg)
	}

	return cphr, nil
}

// nameAlgHashFromPublic extracts the name algorithm from a public area and
// returns a function to generate a new hash.Hash implementing that algorithm.
func nameAlgHashFromPublic(pub tpm2.Public) (func() hash.Hash, error) {
	switch pub.NameAlg {
	case tpm2.AlgSHA1:
		return sha1.New, nil

	case tpm2.AlgSHA256:
		return sha256.New, nil

	case tpm2.AlgSHA384:
		return sha512.New384, nil

	case tpm2.AlgSHA512:
		return sha512.New, nil
	}

	return nil, fmt.Errorf("unsupported hash algorithm: %d", pub.NameAlg)
}

// computeName computes and encodes the name of a public area, without the
// leading size field.
func computeName(pub tpm2.Public) ([]byte, error) {
	name, err := pub.Name()
	if err != nil {
		return nil, fmt.Errorf("failed to compute public area name: %w", err)
	}

	nameBytes, err := name.Encode()
	if err != nil {
		return nil, fmt.Errorf("failed to encode public area name: %w", err)
	}

	return nameBytes[sizeFieldLen:], nil
}
