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
    key: 'regex',
    label: 'Regex Realm', // i18n defer
    visible: true
  },
  {
    key: 'eap',
    label: 'eap configuration',
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
      searchApiHeaders: {
        foo: 'bar'
      },
      defaultSortKeys: [], // use natural ordering
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
          label: i18n.t('Realm'),
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
          label: i18n.t('Regex Realm'),
          text: i18n.t('PacketFence will use this Realm configuration if the regex match with the UserName (optional).'),
          cols: [
            {
              namespace: 'regex',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'regex')
            }
          ]
        },
        {
          label: i18n.t('NTLM Auth Configuration'), labelSize: 'lg'
        },
        {
          label: i18n.t('Domain'),
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
          label: i18n.t('eDirectory'),
          text: i18n.t('The eDirectory server to use for the authentication in that realm.'),
          cols: [
            {
              namespace: 'edir_source',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'edir_source')
            }
          ]
        },
        {
          label: i18n.t('EAP Configuration'), labelSize: 'lg'
        },
        {
          label: i18n.t('EAP'),
          text: i18n.t('The EAP configuration to use.'),
          cols: [
            {
              namespace: 'eap',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'eap')
            }
          ]
        },
	{
          label: i18n.t('Freeradius Proxy Configuration'), labelSize: 'lg'
        },
        {
          label: i18n.t('Realm Options'),
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
          label: i18n.t('RADIUS AUTH'),
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
          label: i18n.t('Type'),
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
          label: i18n.t('Enable Virtual Server'),
          text: i18n.t('If enable then the pre-proxy and post-proxy section are called when the request is proxied'),
          cols: [
            {
              namespace: 'radius_auth_home_server_pool_virtual_server',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Authentication virtual server options'),
          text: i18n.t('Write the unlang definition of the virtual server. This will be used if you enabled Enable Virtual Server.'),
          cols: [
            {
              namespace: 'radius_auth_virtual_server_options',
              component: pfFormTextarea,
              attrs: attributesFromMeta(meta, 'radius_auth_virtual_server_options')
            }
          ]
        },
        {
          label: i18n.t('Authorize from PacketFence'),
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
          label: i18n.t('RADIUS ACCT'),
          text: i18n.t('The RADIUS Server(s) to proxy accounting.'),
          cols: [
            {
              namespace: 'radius_acct',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'radius_acct')
            }
          ]
        },
        {
          label: i18n.t('Type'),
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
          label: i18n.t('Enable Virtual Server'),
          text: i18n.t('If enable then the pre-proxy and post-proxy section are called when the request is proxied'),
          cols: [
            {
              namespace: 'radius_acct_home_server_pool_virtual_server',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Accounting virtual server options'),
          text: i18n.t('Write the unlang definition of the virtual server. This will be used if you enabled Enable Virtual Server.'),
          cols: [
            {
              namespace: 'radius_acct_virtual_server_options',
              component: pfFormTextarea,
              attrs: attributesFromMeta(meta, 'radius_acct_virtual_server_options')
            }
          ]
        },
        {
          label: i18n.t('Freeradius Eduroam Proxy Configuration'), labelSize: 'lg'
        },
        {
          label: i18n.t('Eduroam Realm Options'),
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
          label: i18n.t('Eduroam RADIUS AUTH'),
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
          label: i18n.t('Type'),
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
          label: i18n.t('Authorize from PacketFence'),
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
          label: i18n.t('Eduroam RADIUS ACCT'),
          text: i18n.t('The RADIUS Server(s) to proxy accounting.'),
          cols: [
            {
              namespace: 'eduroam_radius_acct',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'eduroam_radius_acct')
            }
          ]
        },
        {
          label: i18n.t('Type'),
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
          label: i18n.t('Stripping Configuration'), labelSize: 'lg'
        },
        {
          label: i18n.t('Strip on the portal'),
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
          label: i18n.t('Strip on the admin'),
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
          label: i18n.t('Strip in RADIUS authorization'),
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
          label: i18n.t('Custom attributes'),
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
          label: i18n.t('LDAP source'),
          text: i18n.t('The LDAP Server to query the custom attributes.'),
          cols: [
            {
              namespace: 'ldap_source',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'ldap_source')
            }
          ]
        },
        {
          label: i18n.t('EAP TTLS'), labelSize: 'lg'
        },
        {
          label: i18n.t('LDAP Source for TTLS PAP'),
          text: i18n.t('The LDAP Server to use for EAP TTLS PAP authorization and authentication.'),
          cols: [
            {
              namespace: 'ldap_source_ttls_pap',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'ldap_source_ttls_pap')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    permit_custom_attributes
  } = form
  const {
    isNew = false,
    isClone = false,
    tenantId
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', 'Realm'),
      ...{
        [i18n.t('Realm exists.')]: not(and(required, conditional(isNew || isClone), hasRealms(tenantId), realmExists(tenantId)))
      }
    },
    eap: validatorsFromMeta(meta, 'eap', i18n.t('EAP')),
    domain: validatorsFromMeta(meta, 'domain', i18n.t('Domain')),
    options: validatorsFromMeta(meta, 'options', i18n.t('Options')),
    radius_auth: validatorsFromMeta(meta, 'radius_auth', i18n.t('Servers')),
    radius_auth_proxy_type: validatorsFromMeta(meta, 'radius_auth_proxy_type', i18n.t('Type')),
    radius_auth_home_server_pool_virtual_server: validatorsFromMeta(meta, 'radius_auth_home_server_pool_virtual_server', i18n.t('Enable Virtual Server')),
    radius_auth_virtual_server_options: validatorsFromMeta(meta, 'radius_auth_virtual_server_options', i18n.t('Authentication virtual server options')),
    radius_acct: validatorsFromMeta(meta, 'radius_acct', i18n.t('Servers')),
    radius_acct_proxy_type: validatorsFromMeta(meta, 'radius_acct_proxy_type', i18n.t('Type')),
    radius_acct_home_server_pool_virtual_server: validatorsFromMeta(meta, 'radius_acct_home_server_pool_virtual_server', i18n.t('Enable Virtual Server')),
    radius_acct_virtual_server_options: validatorsFromMeta(meta, 'radius_acct_virtual_server_options', i18n.t('Accounting virtual server options')),
    eduroam_options: validatorsFromMeta(meta, 'eduroam_options', 'Realm options'),
    eduroam_radius_auth: validatorsFromMeta(meta, 'eduroam_radius_auth', 'RADIUS AUTH'),
    eduroam_radius_auth_proxy_type: validatorsFromMeta(meta, 'eduroam_radius_auth_proxy_type', 'Type'),
    eduroam_radius_acct: validatorsFromMeta(meta, 'eduroam_radius_acct', 'RADIUS ACCT'),
    eduroam_radius_acct_proxy_type: validatorsFromMeta(meta, 'eduroam_radius_acct_proxy_type', 'Type'),
    ldap_source: {
      ...validatorsFromMeta(meta, 'ldap_source', i18n.t('Source')),
      ...((permit_custom_attributes === 'enabled')
        ? {
          [i18n.t('LDAP Source required.')]: required
        }
        : {}
      )
    },
    ldap_source_ttls_pap: validatorsFromMeta(meta, 'ldap_source_ttls_pap', i18n.t('Source')),
    edir_source: validatorsFromMeta(meta, 'edir_source', i18n.t('Source'))
  }
}
