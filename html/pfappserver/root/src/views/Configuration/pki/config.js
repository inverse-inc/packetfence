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
  { value: '0', text: 'KEY_ECDSA', sizes: [ '256', '384', '521' ] },
  { value: '1', text: 'KEY_RSA', sizes: [ '2048', '4096' ] },
  { value: '2', text: 'KEY_DSA', sizes: [ '1024', '2048', '3071' ] }
]

export const keySizes = [...(new Set(
    keyTypes.reduce((sizes, type) => ([ ...sizes, ...type.sizes.map(size => +size) ]), [])
  ))]
  .sort((a, b) => (a > b))
  .map(size => ({ value: `${size}`, text: `${size}` }))

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
