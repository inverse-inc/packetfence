import countries from '@/globals/countries'
import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  revokeReasons
} from './'

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
    key: 'revoked',
    label: 'Revoked', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'crl_reason',
    label: 'Reason', // i18n defer
    sortable: true,
    sortByFormatted: true,
    visible: true
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
      return { name: 'pkiRevokedCert', params: { id: item.ID } }
    },
    searchPlaceholder: i18n.t('Search by identifier, certificate authority, template, common name or email'),
    searchableOptions: {
      searchApiEndpoint: 'pki/revokedcerts',
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
      defaultRoute: { name: 'pkiRevokedCerts' }
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

export const view = (_, meta = {}) => {
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
          label: i18n.t('Certificate Template'),
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
          label: i18n.t('Common Name'),
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
          label: i18n.t('Email'),
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
          label: i18n.t('Revoked'),
          cols: [
            {
              namespace: 'revoked',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Reason'),
          cols: [
            {
              namespace: 'crl_reason',
              component: pfFormChosen,
              attrs: {
                options: revokeReasons,
                disabled: (!isNew && !isClone)
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = () => ({})
