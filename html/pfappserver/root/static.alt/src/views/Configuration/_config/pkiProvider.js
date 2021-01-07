import Vue from 'vue'
import store from '@/store'
import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasPkiProviders,
  pkiProviderExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: 'Name', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'description',
    label: 'Description', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'type',
    label: 'Type', // i18n defer
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
    value: 'id',
    text: i18n.t('Name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'description',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'type',
    text: i18n.t('Type'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'pki_provider', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by name or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/pki_providers',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'description', op: 'contains', value: null },
            { field: 'type', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'pki_providers' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: quickCondition },
            { field: 'description', op: 'contains', value: quickCondition },
            { field: 'type', op: 'contains', value: quickCondition }
          ]
        }]
      }
    }
  }
}

export const view = (_, meta = {}) => {
  const {
    isNew = false,
    isClone = false,
    providerType = null
  } = meta

  let pkiProfiles = Vue.observable([])
  if (['packetfence_pki'].includes(providerType)) {
    store.dispatch('$_pkis/allProfiles').then(profiles => {
      profiles.map((profile, index) => {
        Vue.set(pkiProfiles, index, { text: `${profile.ca_name} - ${profile.name}`, value: profile.ID })
      })
    })
  }

  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('PKI Provider Name'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              }
            }
          ]
        },
        {
          if: ['scep'].includes(providerType),
          label: 'URL',
          text: i18n.t('The url used to connect to the SCEP PKI service.'),
          cols: [
            {
              namespace: 'url',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'url')
            }
          ]
        },
        {
          if: ['scep'].includes(providerType),
          label: i18n.t('Username'),
          text: i18n.t('Username to connect to the SCEP PKI Service.'),
          cols: [
            {
              namespace: 'username',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'username')
            }
          ]
        },
        {
          if: ['scep'].includes(providerType),
          label: i18n.t('Password'),
          text: i18n.t('Password for the username filled in above.'),
          cols: [
            {
              namespace: 'password',
              component: pfFormPassword,
              attrs: attributesFromMeta(meta, 'password')
            }
          ]
        },
        {
          if: ['packetfence_pki'].includes(providerType),
          label: i18n.t('Template'),
          text: i18n.t('Template used for the generation of certificate.'),
          cols: [
            {
              namespace: 'profile',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'profile'),
                ...{
                  options: pkiProfiles
                }
              }
            }
          ]
        },
        {
          if: ['packetfence_pki', 'scep'].includes(providerType),
          label: i18n.t('Country'),
          text: i18n.t('Country for the certificate.'),
          cols: [
            {
              namespace: 'country',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'country')
            }
          ]
        },
        {
          if: ['packetfence_pki', 'scep'].includes(providerType),
          label: i18n.t('State'),
          text: i18n.t('State for the certificate.'),
          cols: [
            {
              namespace: 'state',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'state')
            }
          ]
        },
        {
          if: ['packetfence_pki'].includes(providerType),
          label: i18n.t('Street Address'),
          text: i18n.t('Street address for the certificate.'),
          cols: [
            {
              namespace: 'streetaddress',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'streetaddress')
            }
          ]
        },
        {
          if: ['packetfence_pki'].includes(providerType),
          label: i18n.t('Postal Code'),
          text: i18n.t('Postal Code for the certificate.'),
          cols: [
            {
              namespace: 'postalcode',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'postalcode')
            }
          ]
        },
        {
          if: ['packetfence_pki', 'scep'].includes(providerType),
          label: i18n.t('Locality'),
          text: i18n.t('Locality for the certificate.'),
          cols: [
            {
              namespace: 'locality',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'locality')
            }
          ]
        },
        {
          if: ['packetfence_pki', 'scep'].includes(providerType),
          label: i18n.t('Organization'),
          text: i18n.t('Organization for the certificate.'),
          cols: [
            {
              namespace: 'organization',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'organization')
            }
          ]
        },
        {
          if: ['scep'].includes(providerType),
          label: i18n.t('Organizational unit'),
          text: i18n.t('Organizational unit for the certificate.'),
          cols: [
            {
              namespace: 'organizational_unit',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'organizational_unit')
            }
          ]
        },
        {
          if: ['packetfence_pki', 'scep'].includes(providerType),
          label: i18n.t('Common Name Attribute'),
          text: i18n.t('Defines what attribute of the node to use as the common name during the certificate generation.'),
          cols: [
            {
              namespace: 'cn_attribute',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'cn_attribute')
            }
          ]
        },
        {
          if: ['packetfence_pki', 'scep'].includes(providerType),
          label: i18n.t('Common Name Format'),
          text: i18n.t('Defines how the common name will be formated. %s will expand to the defined Common Name Attribute value.'),
          cols: [
            {
              namespace: 'cn_format',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'cn_format')
            }
          ]
        },
        {
          if: ['packetfence_pki'].includes(providerType),
          label: i18n.t('Revoke on unregistration'),
          text: i18n.t('Check this box to have the certificate revoke when the node using it is unregistered. Do not use if multiple devices share the same certificate.'),
          cols: [
            {
              namespace: 'revoke_on_unregistration',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          if: ['packetfence_local'].includes(providerType),
          label: i18n.t('Client cert path'),
          text: i18n.t('Path of the client cert that will be used to generate the p12.'),
          cols: [
            {
              namespace: 'client_cert_path',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'client_cert_path')
            }
          ]
        },
        {
          if: ['packetfence_local'].includes(providerType),
          label: i18n.t('Client key path'),
          text: i18n.t('Path of the client key that will be used to generate the p12.'),
          cols: [
            {
              namespace: 'client_key_path',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'client_key_path')
            }
          ]
        },
        {
          if: ['packetfence_local', 'packetfence_pki', 'scep'].includes(providerType),
          label: i18n.t('CA cert path'),
          text: i18n.t('Path of the CA certificate used to generate client certificate/key combination.'),
          cols: [
            {
              namespace: 'ca_cert_path',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'ca_cert_path')
            }
          ]
        },
        {
          if: ['packetfence_local', 'packetfence_pki', 'scep'].includes(providerType),
          label: i18n.t('Server cert path'),
          text: i18n.t('Path of the RADIUS server authentication certificate.'),
          cols: [
            {
              namespace: 'server_cert_path',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'server_cert_path')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (_, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', i18n.t('Name')),
      ...{
        [i18n.t('PKI Provider exists.')]: not(and(required, conditional(isNew || isClone), hasPkiProviders, pkiProviderExists))
      }
    },
    url: validatorsFromMeta(meta, 'url', 'URL'),
    proto: validatorsFromMeta(meta, 'proto', i18n.t('Protocol')),
    host: validatorsFromMeta(meta, 'host', i18n.t('Host')),
    port: validatorsFromMeta(meta, 'port', i18n.t('Port')),
    username: validatorsFromMeta(meta, 'username', i18n.t('Username')),
    password: validatorsFromMeta(meta, 'password', i18n.t('Password')),
    profile: validatorsFromMeta(meta, 'profile', i18n.t('Profile')),
    country: validatorsFromMeta(meta, 'country', i18n.t('Country')),
    state: validatorsFromMeta(meta, 'state', i18n.t('State')),
    locality: validatorsFromMeta(meta, 'locality', i18n.t('Locality')),
    organization: validatorsFromMeta(meta, 'organization', i18n.t('Organization')),
    organizational_unit: validatorsFromMeta(meta, 'organizational_unit', i18n.t('Unit')),
    cn_attribute: validatorsFromMeta(meta, 'cn_attribute', i18n.t('Attribute')),
    cn_format: validatorsFromMeta(meta, 'cn_format', i18n.t('Format')),
    client_cert_path: validatorsFromMeta(meta, 'client_cert_path', i18n.t('Path')),
    client_key_path: validatorsFromMeta(meta, 'client_key_path', i18n.t('Path')),
    ca_cert_path: validatorsFromMeta(meta, 'ca_cert_path', i18n.t('Path')),
    server_cert_path: validatorsFromMeta(meta, 'server_cert_path', i18n.t('Path'))
  }
}
