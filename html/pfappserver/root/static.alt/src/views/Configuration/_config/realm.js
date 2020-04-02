import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasRealms,
  realmExists
} from '@/globals/pfValidators'

const {
  required
} = require('vuelidate/lib/validators')

export const columns = [
  {
    key: 'id',
    label: 'Name', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'domain',
    label: 'Domain', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'radius_auth',
    label: 'RADIUS Authentication', // i18n defer
    visible: true
  },
  {
    key: 'radius_acct',
    label: 'RADIUS Accounting', // i18n defer
    visible: true
  },
  {
    key: 'portal_strip_username',
    label: 'Strip Portal', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'admin_strip_username',
    label: 'Strip Admin', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'radius_strip_username',
    label: 'Strip RADIUS', // i18n defer
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
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = (context = {}) => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'realm', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by name'),
    searchableOptions: {
      searchApiEndpoint: 'config/realms',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'realms' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: 'Realm', // i18n defer
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
          label: 'NTLM Auth Configuration', // i18n defer labelSize: 'lg'
        },
        {
          label: 'Domain', // i18n defer
          text: i18n.t('The domain to use for the authentication in that realm.'),
          cols: [
            {
              namespace: 'domain',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'domain')
            }
          ]
        },
        {
          label: 'Freeradius Proxy Configuration', // i18n defer labelSize: 'lg'
        },
        {
          label: 'Realm Options', // i18n defer
          text: i18n.t('You can add FreeRADIUS options in the realm definition.'),
          cols: [
            {
              namespace: 'options',
              component: pfFormTextarea,
              attrs: attributesFromMeta(meta, 'options')
            }
          ]
        },
        {
          label: 'RADIUS AUTH', // i18n defer
          text: i18n.t('The RADIUS Server(s) to proxy authentication.'),
          cols: [
            {
              namespace: 'radius_auth',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'radius_auth')
            }
          ]
        },
        {
          label: 'Type', // i18n defer
          text: i18n.t('Home server pool type.'),
          cols: [
            {
              namespace: 'radius_auth_proxy_type',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'radius_auth_proxy_type')
            }
          ]
        },
        {
          label: 'Authorize from PacketFence', // i18n defer
          text: i18n.t('Should we forward the request to PacketFence to have a dynamic answer or do we use the remote proxy server answered attributes?'),
          cols: [
            {
              namespace: 'radius_auth_compute_in_pf',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'RADIUS ACCT', // i18n defer
          text: i18n.t('The RADIUS Server(s) to proxy accounting.'),
          cols: [
            {
              namespace: 'radius_acct_chosen',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'radius_acct_chosen')
            }
          ]
        },
        {
          label: 'Type', // i18n defer
          text: i18n.t('Home server pool type.'),
          cols: [
            {
              namespace: 'radius_acct_proxy_type',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'radius_acct_proxy_type')
            }
          ]
        },
        {
          label: 'Freeradius Eduroam Proxy Configuration', // i18n defer labelSize: 'lg'
        },
        {
          label: 'Eduroam Realm Options', // i18n defer
          text: i18n.t('You can add Eduroam FreeRADIUS options in the realm definition.'),
          cols: [
            {
              namespace: 'eduroam_options',
              component: pfFormTextarea,
              attrs: attributesFromMeta(meta, 'eduroam_options')
            }
          ]
        },
        {
          label: 'Eduroam RADIUS AUTH', // i18n defer
          text: i18n.t('The RADIUS Server(s) to proxy authentication.'),
          cols: [
            {
              namespace: 'eduroam_radius_auth',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'eduroam_radius_auth')
            }
          ]
        },
        {
          label: 'Type', // i18n defer
          text: i18n.t('Home server pool type.'),
          cols: [
            {
              namespace: 'eduroam_radius_auth_proxy_type',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'eduroam_radius_auth_proxy_type')
            }
          ]
        },
        {
          label: 'Authorize from PacketFence', // i18n defer
          text: i18n.t('Should we forward the request to PacketFence to have a dynamic answer or do we use the remote proxy server answered attributes?'),
          cols: [
            {
              namespace: 'eduroam_radius_auth_compute_in_pf',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Eduroam RADIUS ACCT', // i18n defer
          text: i18n.t('The RADIUS Server(s) to proxy accounting.'),
          cols: [
            {
              namespace: 'eduroam_radius_acct_chosen',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'eduroam_radius_acct_chosen')
            }
          ]
        },
        {
          label: 'Type', // i18n defer
          text: i18n.t('Home server pool type.'),
          cols: [
            {
              namespace: 'eduroam_radius_acct_proxy_type',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'eduroam_radius_acct_proxy_type')
            }
          ]
        },
        {
          label: 'Stripping Configuration', // i18n defer labelSize: 'lg'
        },
        {
          label: 'Strip on the portal', // i18n defer
          text: i18n.t('Should the usernames matching this realm be stripped when used on the captive portal.'),
          cols: [
            {
              namespace: 'portal_strip_username',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Strip on the admin', // i18n defer
          text: i18n.t('Should the usernames matching this realm be stripped when used on the administration interface.'),
          cols: [
            {
              namespace: 'admin_strip_username',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Strip in RADIUS authorization', // i18n defer
          text: i18n.t(`Should the usernames matching this realm be stripped when used in the authorization phase of 802.1x.\nNote that this doesn't control the stripping in FreeRADIUS, use the options above for that.`),
          cols: [
            {
              namespace: 'radius_strip_username',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Custom attributes', // i18n defer
          text: i18n.t('Allow to use custom attributes to authenticate 802.1x users (attributes are defined in the source).'),
          cols: [
            {
              namespace: 'permit_custom_attributes',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'LDAP source', // i18n defer
          text: i18n.t('The LDAP Server to query the custom attributes.'),
          cols: [
            {
              namespace: 'ldap_source',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'ldap_source')
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
    id: {
      ...validatorsFromMeta(meta, 'id', 'ID'),
      ...{
        [i18n.t('Role exists.')]: not(and(required, conditional(isNew || isClone), hasRealms, realmExists))
      }
    },
    domain: validatorsFromMeta(meta, 'domain', i18n.t('Domain')),
    options: validatorsFromMeta(meta, 'options', i18n.t('Options')),
    radius_auth: validatorsFromMeta(meta, 'radius_auth', i18n.t('Servers')),
    radius_auth_proxy_type: validatorsFromMeta(meta, 'radius_auth_proxy_type', i18n.t('Type')),
    radius_acct_chosen: validatorsFromMeta(meta, 'radius_acct_chosen', i18n.t('Servers')),
    radius_acct_proxy_type: validatorsFromMeta(meta, 'radius_acct_proxy_type', i18n.t('Type')),
    eduroam_options: validatorsFromMeta(meta, 'eduroam_options', 'Realm options'),
    eduroam_radius_auth: validatorsFromMeta(meta, 'eduroam_radius_auth', 'RADIUS AUTH'),
    eduroam_radius_auth_proxy_type: validatorsFromMeta(meta, 'eduroam_radius_auth_proxy_type', 'Type'),
    eduroam_radius_acct_chosen: validatorsFromMeta(meta, 'eduroam_radius_acct_chosen', 'RADIUS ACCT'),
    eduroam_radius_acct_proxy_type: validatorsFromMeta(meta, 'eduroam_radius_acct_proxy_type', 'Type'),
    ldap_source: validatorsFromMeta(meta, 'ldap_source', i18n.t('Source'))
  }
}
