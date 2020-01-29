import Vue from 'vue'
import countries from '@/globals/countries'
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
  required,
  minValue,
  email,
  maxLength,
  minLength
} from 'vuelidate/lib/validators'
import {
  digests,
  keyTypes,
  keySizes,
  keyUsages,
  extendedKeyUsages
} from './'

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

export const decomposeCa = (item) => {
  const { key_usage = null, extended_key_usage = null } = item
  return { ...item, ...{
    key_usage: key_usage.split('|'),
    extended_key_usage: extended_key_usage.split('|')
  } }
}

export const recomposeCa = (item) => {
  const { key_usage = null, extended_key_usage = null } = item
  return { ...item, ...{
    key_usage: key_usage.join('|'),
    extended_key_usage: extended_key_usage.join('|')
  } }
}

export const view = (form = {}, meta = {}) => {
  const {
    key_type = null,
    key_size = null,
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
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: Object.keys(countries).map(countryCode => {
                  return { value: countryCode, text: countries[countryCode] }
                })
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
          label: i18n.t('Street Address'),
          cols: [
            {
              namespace: 'street_address',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Postal Code'),
          cols: [
            {
              namespace: 'postal_code',
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
              namespace: 'key_type',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: keyTypes
              },
              listeners: {
                select: (event) => {
                  const { value: key_type } = event
                  if (keySizes[key_type].filter(option => { // does key_size exist in new key_type?
                    return option.value === key_size
                  }).length === 0) { // key_size does not exist in new key_type
                    Vue.set(form, 'key_size', null) // clear key_size
                  }
                }
              }
            }
          ]
        },
        {
          if: key_type,
          label: i18n.t('Key size'),
          cols: [
            {
              namespace: 'key_size',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: (key_type in keySizes) ? keySizes[key_type] : []
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
              namespace: 'key_usage',
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
              namespace: 'extended_key_usage',
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
      [i18n.t('Common name exists.')]: not(and(required, conditional(isNew || isClone), hasPkiCas, pkiCaCnExists)),
      [i18n.t('Maximum 64 characters.')]: maxLength(64)
    },
    mail: {
      [i18n.t('Email required.')]: required,
      [i18n.t('Invalid email address.')]: email,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    organisation: {
      [i18n.t('Organisation required.')]: required,
      [i18n.t('Maximum 64 characters.')]: maxLength(64)
    },
    country: {
      [i18n.t('Country required.')]: required
    },
    state: {
      [i18n.t('State required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    locality: {
      [i18n.t('Locality required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    street_address: {
      [i18n.t('Street address required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    postal_code: {
      [i18n.t('Postal code required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    key_type: {
      [i18n.t('Key type required.')]: required
    },
    key_size: {
      [i18n.t('Key size required.')]: required
    },
    digest: {
      [i18n.t('Digest required.')]: required
    },
    days: {
      [i18n.t('Days required.')]: required,
      [i18n.t('Minimum 1 day(s).')]: minValue(1)
    }
  }
}
