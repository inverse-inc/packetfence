export const digests = {
  0: 'UnknownSignatureAlgorithm',
  1: 'MD2WithRSA',
  2: 'MD5WithRSA',
  3: 'SHA1WithRSA',
  4: 'SHA256WithRSA',
  5: 'SHA384WithRSA',
  6: 'SHA512WithRSA',
  7: 'DSAWithSHA1',
  8: 'DSAWithSHA256',
  9: 'ECDSAWithSHA1',
  10: 'ECDSAWithSHA256',
  11: 'ECDSAWithSHA384',
  12: 'ECDSAWithSHA512',
  13: 'SHA256WithRSAPSS',
  14: 'SHA384WithRSAPSS',
  15: 'SHA512WithRSAPSS',
  16: 'PureEd25519'
}

export const keyTypes = {
  0: ['KEY_ECDSA', [256, 384, 521]],
  1: ['KEY_RSA', [2048, 4096]],
  2: ['KEY_DSA', [1024, 2048, 3071]]
}

export const keyUsages = {
  1: 'DigitalSignature',
  2: 'ContentCommitment',
  4: 'KeyEncipherment',
  8: 'DataEncipherment',
  16: 'KeyAgreement',
  32: 'CertSign',
  64: 'CRLSign',
  128: 'EncipherOnly',
  256: 'DecipherOnly'
}

export const extendedKeyUsages = {
  0: 'Any',
  1: 'ServerAuth',
  2: 'ClientAuth',
  3: 'CodeSigning',
  4: 'EmailProtection',
  5: 'IPSECEndSystem',
  6: 'IPSECTunnel',
  7: 'IPSECUser',
  8: 'TimeStamping',
  9: 'OCSPSigning',
  10: 'MicrosoftServerGatedCrypto',
  11: 'NetscapeServerGatedCrypto',
  12: 'MicrosoftCommercialCodeSigning',
  13: 'MicrosoftKernelCodeSigning'
}

export const revokeReasons = {
  0: 'Unspecified',
  1: 'KeyCompromise',
  2: 'CACompromise',
  3: 'AffiliationChanged',
  4: 'Superseded',
  5: 'CessationOfOperation',
  6: 'CertificateHold',
  8: 'RemoveFromCRL',
  9: 'PrivilegeWithdrawn',
  10: 'AACompromise'
}

export default {
  digests,
  keyUsages,
  extendedKeyUsages,
  revokeReasons
}