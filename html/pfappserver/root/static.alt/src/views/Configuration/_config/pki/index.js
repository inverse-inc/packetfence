export const digests = [
  { value: '0', text: 'UnknownSignatureAlgorithm' },
  { value: '1', text: 'MD2WithRSA' },
  { value: '2', text: 'MD5WithRSA' },
  { value: '3', text: 'SHA1WithRSA' },
  { value: '4', text: 'SHA256WithRSA' },
  { value: '5', text: 'SHA384WithRSA' },
  { value: '6', text: 'SHA512WithRSA' },
  { value: '7', text: 'DSAWithSHA1' },
  { value: '8', text: 'DSAWithSHA256' },
  { value: '9', text: 'ECDSAWithSHA1' },
  { value: '10', text: 'ECDSAWithSHA256' },
  { value: '11', text: 'ECDSAWithSHA384' },
  { value: '12', text: 'ECDSAWithSHA512' },
  { value: '13', text: 'SHA256WithRSAPSS' },
  { value: '14', text: 'SHA384WithRSAPSS' },
  { value: '15', text: 'SHA512WithRSAPSS' },
  { value: '16', text: 'PureEd25519' }
]

export const keyTypes = [
  { value: '0', text: 'KEY_ECDSA' },
  { value: '1', text: 'KEY_RSA' },
  { value: '2', text: 'KEY_DSA' }
]

export const keySizes = {
  0: [ // KEY_ECDSA
    { value: '256', text: '256' },
    { value: '384', text: '384' },
    { value: '521', text: '521' }
  ],
  1: [ // KEY_RSA
    { value: '2048', text: '2048' },
    { value: '4096', text: '4096' }
  ],
  2: [ // KEY_DSA
    { value: '1024', text: '1024' },
    { value: '2048', text: '2048' },
    { value: '3072', text: '3072' }
  ]
}

export const keyUsages = [
  { value: '1', text: 'DigitalSignature' },
  { value: '2', text: 'ContentCommitment' },
  { value: '4', text: 'KeyEncipherment' },
  { value: '8', text: 'DataEncipherment' },
  { value: '16', text: 'KeyAgreement' },
  { value: '32', text: 'CertSign' },
  { value: '64', text: 'CRLSign' },
  { value: '128', text: 'EncipherOnly' },
  { value: '256', text: 'DecipherOnly' }
]

export const extendedKeyUsages = [
  { value: '0', text: 'Any' },
  { value: '1', text: 'ServerAuth' },
  { value: '2', text: 'ClientAuth' },
  { value: '3', text: 'CodeSigning' },
  { value: '4', text: 'EmailProtection' },
  { value: '5', text: 'IPSECEndSystem' },
  { value: '6', text: 'IPSECTunnel' },
  { value: '7', text: 'IPSECUser' },
  { value: '8', text: 'TimeStamping' },
  { value: '9', text: 'OCSPSigning' },
  { value: '10', text: 'MicrosoftServerGatedCrypto' },
  { value: '11', text: 'NetscapeServerGatedCrypto' },
  { value: '12', text: 'MicrosoftCommercialCodeSigning' },
  { value: '13', text: 'MicrosoftKernelCodeSigning' }
]

export const revokeReasons = [
  { value: '0', text: 'Unspecified' },
  { value: '1', text: 'KeyCompromise' },
  { value: '2', text: 'CACompromise' },
  { value: '3', text: 'AffiliationChanged' },
  { value: '4', text: 'Superseded' },
  { value: '5', text: 'CessationOfOperation' },
  { value: '6', text: 'CertificateHold' },
  { value: '8', text: 'RemoveFromCRL' },
  { value: '9', text: 'PrivilegeWithdrawn' },
  { value: '10', text: 'AACompromise' }
]
