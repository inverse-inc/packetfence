import store from '@/store'
import countries from '@/globals/countries'
import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasPkiCerts,
  pkiCertCnExists
} from '@/globals/pfValidators'
import {
  email,
  required,
  maxLength
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'ID',
    label: 'Identifier', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'ca_id',
    required: true
  },
  {
    key: 'ca_name',
    label: 'Certificate Authority', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'profile_id',
    required: true
  },
  {
    key: 'profile_name',
    label: 'Template', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'cn',
    label: 'Common Name', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'mail',
    label: 'Email', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'valid_until',
    label: 'Valid Until', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const fields = [
  {
    value: 'ID',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'ca_id',
    text: i18n.t('Certificate Authority Identifier'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'ca_name',
    text: i18n.t('Certificate Authority Name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'profile_id',
    text: i18n.t('Template Identifier'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'profile_name',
    text: i18n.t('Template Name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'cn',
    text: i18n.t('Common Name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'mail',
    text: i18n.t('Email'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'pkiCert', params: { id: item.ID } }
    },
    searchPlaceholder: i18n.t('Search by identifier, certificate authority, template, common name or email'),
    searchableOptions: {
      searchApiEndpoint: 'pki/certs',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'ca_name', op: 'contains', value: null },
            { field: 'profile_name', op: 'contains', value: null },
            { field: 'cn', op: 'contains', value: null },
            { field: 'mail', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'pkiCerts' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'ca_name', op: 'contains', value: quickCondition },
              { field: 'profile_name', op: 'contains', value: quickCondition },
              { field: 'cn', op: 'contains', value: quickCondition },
              { field: 'mail', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const download = (id, password, filename='cert.p12') => {
  return new Promise((resolve, reject) => {
    store.dispatch('$_pkis/downloadCert', { id, password }).then(arrayBuffer => {
      const blob = new Blob([arrayBuffer], { type: 'application/x-pkcs12' })
      if (window.navigator.msSaveOrOpenBlob) {
        window.navigator.msSaveBlob(blob, filename)
      } else {
        let elem = window.document.createElement('a')
        elem.href = window.URL.createObjectURL(blob)
        elem.download = filename
        document.body.appendChild(elem)
        elem.click()
        document.body.removeChild(elem)
      }
      resolve()
    }).catch(e => {
      reject(e)
    })
  })
}

export const revoke = (id, reason) => {
  return store.dispatch('$_pkis/revokeCert', { id, reason })
}

export const view = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false,
    profiles = []
  } = meta
  return [
    {
      tab: null,
      rows: [
        {
          if: (!isNew && !isClone),
          label: 'Identifier', // i18n defer
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
          label: 'Certificate Template', // i18n defer
          text: i18n.t('Certificate template used for this certificate.'),
          cols: [
            {
              namespace: 'profile_id',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: profiles.map(profile => { return { value: profile.ID.toString(), text: `${profile.ca_name} - ${profile.name}` } })
              }
            }
          ]
        },
        {
          label: 'Common Name', // i18n defer
          text: i18n.t('Username for this certificate.'),
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
          label: 'Email', // i18n defer
          text: i18n.t('Email address of the user. The email with the certificate will be sent to this address.'),
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
          label: 'Organisation', // i18n defer
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
          label: 'Country', // i18n defer
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
          label: 'State or Province', // i18n defer
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
          label: 'Locality', // i18n defer
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
          label: 'Street Address', // i18n defer
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
          label: 'Postal Code', // i18n defer
          cols: [
            {
              namespace: 'postal_code',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
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
    profile_id: {
      [i18n.t('Template required.')]: required
    },
    cn: {
      [i18n.t('Common Name required.')]: required,
      [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasPkiCerts, pkiCertCnExists)),
      [i18n.t('Maximum 64 characters.')]: maxLength(64)
    },
    mail: {
      [i18n.t('Invalid email address.')]: email
    },
    organisation: {
      [i18n.t('Maximum 64 characters.')]: maxLength(64)
    },
    state: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    locality: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    street_address: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    postal_code: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    }
  }
}
