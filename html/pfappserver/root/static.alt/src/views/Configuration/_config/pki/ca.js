import Vue from 'vue'
import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  and,
  not,
  conditional,
  hasPkiCas,
  pkiCaCnExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'ID',
    label: i18n.t('Identifier'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'cn',
    label: i18n.t('Common Name'),
    sortable: true,
    visible: true
  },
  {
    key: 'mail',
    label: i18n.t('Email'),
    sortable: true,
    visible: true
  },
  {
    key: 'organisation',
    label: i18n.t('Organisation'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

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
    { value: '512', text: '512' },
    { value: '1024', text: '1024' },
    { value: '2048', text: '2048' }
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

export const decomposeCa = (item) => {
  const { keyusage = null, extendedkeyusage = null } = item
  return { ...item, ...{
    keyusage: keyusage.split('|'),
    extendedkeyusage: extendedkeyusage.split('|')
  } }
}

export const recomposeCa = (item) => {
  const { keyusage = null, extendedkeyusage = null } = item
  return { ...item, ...{
    keyusage: keyusage.join('|'),
    extendedkeyusage: extendedkeyusage.join('|')
  } }
}

export const view = (form = {}, meta = {}) => {
  const {
    keytype = null,
    keysize = null,
    cert = null
  } = form
  const {
    isNew = false,
    isClone = false
  } = meta
  return [
    {
      tab: null,
      rows: [
        {
          if: (!isNew && !isClone),
          label: i18n.t('Identifier'),
          cols: [
            {
              namespace: 'ID',
              component: pfFormInput,
              attrs: {
                disabled: true
              }
            }
          ]
        },
        {
          label: i18n.t('Common Name'),
          cols: [
            {
              namespace: 'cn',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Email'),
          cols: [
            {
              namespace: 'mail',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Organisation'),
          cols: [
            {
              namespace: 'organisation',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Country'),
          cols: [
            {
              namespace: 'country',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('State or Province'),
          cols: [
            {
              namespace: 'state',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Locality'),
          cols: [
            {
              namespace: 'locality',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Key type'),
          cols: [
            {
              namespace: 'keytype',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: keyTypes
              },
              listeners: {
                select: (event) => {
                  const { value: keytype } = event
                  if (keySizes[keytype].filter(option => { // does keysize exist in new keytype?
                    return option.value === keysize
                  }).length === 0) { // keysize does not exist in new keytype
                    Vue.set(form, 'keysize', null) // clear keysize
                  }
                }
              }
            }
          ]
        },
        {
          if: keytype,
          label: i18n.t('Key size'),
          cols: [
            {
              namespace: 'keysize',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: (keytype in keySizes) ? keySizes[keytype] : []
              }
            }
          ]
        },
        {
          label: i18n.t('Digest'),
          cols: [
            {
              namespace: 'digest',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: digests
              }
            }
          ]
        },
        {
          label: i18n.t('Key usage'),
          text: i18n.t('Optional. One or many of: digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign, cRLSign, encipherOnly, decipherOnly.'),
          cols: [
            {
              namespace: 'keyusage',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: keyUsages,
                multiple: true
              }
            }
          ]
        },
        {
          label: i18n.t('Extended key usage'),
          text: i18n.t('Optional. One or many of: serverAuth, clientAuth, codeSigning, emailProtection, timeStamping, msCodeInd, msCodeCom, msCTLSign, msSGC, msEFS, nsSGC.'),
          cols: [
            {
              namespace: 'extendedkeyusage',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: extendedKeyUsages,
                multiple: true
              }
            }
          ]
        },
        {
          label: i18n.t('Days'),
          text: i18n.t('Number of days the CA will be valid.'),
          cols: [
            {
              namespace: 'days',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone),
                type: 'number'
              }
            }
          ]
        },
        {
          if: (!isNew && !isClone),
          label: i18n.t('Certificate'),
          cols: [
            {
              namespace: 'cert',
              component: pfFormTextarea,
              attrs: {
                disabled: true,
                rows: [...(cert || '')].filter(c => c === '\n').length + 1
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    cn: {
      [i18n.t('Common name required.')]: required,
      [i18n.t('Common name exists.')]: not(and(required, conditional(isNew || isClone), hasPkiCas, pkiCaCnExists))
    },
    mail: {
      [i18n.t('Email required.')]: required
    },
    organisation: {
      [i18n.t('Organisation required.')]: required
    },
    country: {
      [i18n.t('Country required.')]: required
    },
    state: {
      [i18n.t('State required.')]: required
    },
    locality: {
      [i18n.t('Locality required.')]: required
    },
    keytype: {
      [i18n.t('Key type required.')]: required
    },
    keysize: {
      [i18n.t('Key size required.')]: required
    },
    digest: {
      [i18n.t('Digest required.')]: required
    },
    days: {
      [i18n.t('Days required.')]: required
    }
  }
}
