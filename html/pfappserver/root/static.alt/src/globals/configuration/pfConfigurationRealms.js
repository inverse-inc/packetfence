import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
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

export const pfConfigurationRealmsListColumns = [
  {
    key: 'id',
    label: i18n.t('Name'),
    sortable: true,
    visible: true
  },
  {
    key: 'domain',
    label: i18n.t('Domain'),
    sortable: true,
    visible: true
  },
  {
    key: 'radius_auth',
    label: i18n.t('Radius Authentication'),
    sortable: false,
    visible: true
  },
  {
    key: 'radius_acct',
    label: i18n.t('Radius Accounting'),
    sortable: false,
    visible: true
  },
  {
    key: 'portal_strip_username',
    label: i18n.t('Strip Portal'),
    sortable: true,
    visible: true
  },
  {
    key: 'admin_strip_username',
    label: i18n.t('Strip Admin'),
    sortable: true,
    visible: true
  },
  {
    key: 'radius_strip_username',
    label: i18n.t('Strip RADIUS'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    sortable: false,
    visible: true,
    locked: true
  }
]

export const pfConfigurationRealmsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationRealmListConfig = (context = {}) => {
  const { $i18n } = context
  return {
    columns: pfConfigurationRealmsListColumns,
    fields: pfConfigurationRealmsListFields,
    rowClickRoute (item, index) {
      return { name: 'realm', params: { id: item.id } }
    },
    searchPlaceholder: $i18n.t('Search by name'),
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

export const pfConfigurationRealmViewFields = (context = {}) => {
  const {
    isNew = false,
    isClone = false,
    options: {
      meta = {}
    }
  } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          label: i18n.t('Realm'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'id', 'Identifier'),
                ...{
                  [i18n.t('Role exists.')]: not(and(required, conditional(isNew || isClone), hasRealms, realmExists))
                }
              }
            }
          ]
        },
        {
          label: i18n.t('NTLM Auth Configuration'), labelSize: 'lg'
        },
        {
          label: i18n.t('Domain'),
          text: i18n.t('The domain to use for the authentication in that realm.'),
          fields: [
            {
              key: 'domain',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'domain'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'domain', 'Domain')
            }
          ]
        },
        {
          label: i18n.t('Freeradius Proxy Configuration'), labelSize: 'lg'
        },
        {
          label: i18n.t('Realm Options'),
          text: i18n.t('You can add FreeRADIUS options in the realm definition.'),
          fields: [
            {
              key: 'options',
              component: pfFormTextarea,
              attrs: pfConfigurationAttributesFromMeta(meta, 'options'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'options', 'Realm options')
            }
          ]
        },
        {
          label: i18n.t('RADIUS AUTH'),
          text: i18n.t('The RADIUS Server(s) to proxy authentication.'),
          fields: [
            {
              key: 'radius_auth',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'radius_auth'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'radius_auth', 'RADIUS AUTH')
            }
          ]
        },
        {
          label: i18n.t('Type'),
          text: i18n.t('Home server pool type.'),
          fields: [
            {
              key: 'radius_auth_proxy_type',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'radius_auth_proxy_type'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'radius_auth_proxy_type', 'Type')
            }
          ]
        },
        {
          label: i18n.t('Authorize from PacketFence'),
          text: i18n.t('Should we forward the request to PacketFence to have a dynamic answer or do we use the remote proxy server answered attributes?'),
          fields: [
            {
              key: 'radius_auth_compute_in_pf',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('RADIUS ACCT'),
          text: i18n.t('The RADIUS Server(s) to proxy authentication.'),
          fields: [
            {
              key: 'radius_acct_chosen',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'radius_acct_chosen'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'radius_acct_chosen', 'RADIUS ACCT')
            }
          ]
        },
        {
          label: i18n.t('Type'),
          text: i18n.t('Home server pool type.'),
          fields: [
            {
              key: 'radius_acct_proxy_type',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'radius_acct_proxy_type'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'radius_acct_proxy_type', 'Type')
            }
          ]
        },
        {
          label: i18n.t('Stripping Configuration'), labelSize: 'lg'
        },
        {
          label: i18n.t('Strip on the portal'),
          text: i18n.t('Should the usernames matching this realm be stripped when used on the captive portal.'),
          fields: [
            {
              key: 'portal_strip_username',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Strip on the admin'),
          text: i18n.t('Should the usernames matching this realm be stripped when used on the administration interface.'),
          fields: [
            {
              key: 'admin_strip_username',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Strip in RADIUS authorization'),
          text: i18n.t(`Should the usernames matching this realm be stripped when used in the authorization phase of 802.1x.\nNote that this doesn't control the stripping in FreeRADIUS, use the options above for that.`),
          fields: [
            {
              key: 'radius_strip_username',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Custom attributes'),
          text: i18n.t('Allow to use custom attributes to authenticate 802.1x users (attributes are defined in the source).'),
          fields: [
            {
              key: 'permit_custom_attributes',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('LDAP source'),
          text: i18n.t('The LDAP Server to query the custom attributes.'),
          fields: [
            {
              key: 'ldap_source',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'ldap_source'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'ldap_source', 'LDAP source')
            }
          ]
        }
      ]
    }
  ]
}
