import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormHtml from '@/components/pfFormHtml'
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
  hasDomains,
  domainExists
} from '@/globals/pfValidators'

const {
  required
} = require('vuelidate/lib/validators')

export const columns = [
  {
    key: 'id',
    label: 'Identifier', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'workgroup',
    label: 'Workgroup', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'ntlm_cache',
    label: 'NTLM Cache', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'joined',
    label: 'Test Join', // i18n defer
    locked: true
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
    value: 'workgroup',
    text: i18n.t('Workgroup'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'domain', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by name or workgroup'),
    searchableOptions: {
      searchApiEndpoint: 'config/domains',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'workgroup', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'domains' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'workgroup', op: 'contains', value: quickCondition }
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
    isClone = false
  } = meta
  return [
    {
      tab: i18n.t('Settings'),
      rows: [
        {
          label: i18n.t('Identifier'),
          text: i18n.t(`Specify a unique identifier for your configuration.<br/>This doesn't have to be related to your domain.`),
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
          label: i18n.t('Workgroup'),
          cols: [
            {
              namespace: 'workgroup',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'workgroup')
            }
          ]
        },
        {
          label: i18n.t('DNS name of the domain'),
          text: i18n.t('The DNS name (FQDN) of the domain.'),
          cols: [
            {
              namespace: 'dns_name',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'dns_name')
            }
          ]
        },
        {
          label: `This server's name`, // i18n defer
          text: i18n.t(`This server's name (account name) in your Active Directory. Use '%h' to automatically use this server hostname.`),
          cols: [
            {
              namespace: 'server_name',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'server_name')
            }
          ]
        },
        {
          label: i18n.t('Sticky DC'),
          text: i18n.t(`This is used to specify a sticky domain controller to connect to. If not specified, default '*' will be used to connect to any available domain controller.`),
          cols: [
            {
              namespace: 'sticky_dc',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'sticky_dc')
            }
          ]
        },
        {
          label: i18n.t('Active Directory server'),
          text: i18n.t('The IP address or DNS name of your Active Directory server.'),
          cols: [
            {
              namespace: 'ad_server',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'ad_server')
            }
          ]
        },
        {
          label: i18n.t('DNS server(s)'),
          text: i18n.t('The IP address(es) of the DNS server(s) for this domain. Comma delimited if multiple.'),
          cols: [
            {
              namespace: 'dns_servers',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'dns_servers')
            }
          ]
        },
        {
          label: i18n.t('OU'),
          text: i18n.t(`Use a specific OU for the PacketFence account. The OU string read from top to bottom without RDNs and delimited by a '/'. E.g. "Computers/Servers/Unix". IMPORTANT NOTE: Due to a bug in the current version of samba, you will need to precreate a computer object in the OU you specify above when you're not using the default value ('Computers'). Otherwise you will get the following error: "Failed to join domain: failed to precreate account in ou ou=XYZ,dc=ACME,dc=CORP: No such object"`),
          cols: [
            {
              namespace: 'ou',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'ou')
            }
          ]
        },
        {
          label: i18n.t('ntlmv2 only'),
          text: i18n.t('If you enabled "Send NTLMv2 Response Only. Refuse LM & NTLM" (only allow ntlm v2) in Network Security: LAN Manager authentication level'),
          cols: [
            {
              namespace: 'ntlmv2_only',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: '1', unchecked: '0' }
              }
            }
          ]
        },
        {
          label: i18n.t('Allow on registration'),
          text: i18n.t('If this option is enabled, the device will be able to reach the Active Directory from the registration VLAN.'),
          cols: [
            {
              namespace: 'registration',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: '1', unchecked: '0' }
              }
            }
          ]
        },
        {
          label: null, /* no label */
          cols: [
            {
              component: pfFormHtml,
              attrs: {
                html: `<div class="alert alert-warning">
                  <strong>${i18n.t('Note')}</strong>
                  ${i18n.t('"Allow on registration" option requires passthroughs to be enabled as well as configured to allow both the domain DNS name and each domain controllers DNS name (or *.dns name)')}\n${i18n.t('Example: inverse.local, *.inverse.local')}
                </div>`
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('NTLM cache'),
      rows: [
        {
          label: i18n.t('NTLM cache'),
          text: i18n.t('Should the NTLM cache be enabled for this domain?'),
          cols: [
            {
              namespace: 'ntlm_cache',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Source'),
          text: i18n.t('The source to use to connect to your Active Directory server for NTLM caching.'),
          cols: [
            {
              namespace: 'ntlm_cache_source',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'ntlm_cache_source')
            }
          ]
        },
        {
          label: i18n.t('LDAP filter'),
          text: i18n.t('An LDAP query to filter out the users that should be cached.'),
          cols: [
            {
              namespace: 'ntlm_cache_filter',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'ntlm_cache_filter'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Expiration'),
          text: i18n.t('The amount of seconds an entry should be cached. This should be adjusted to twice the value of maintenance.populate_ntlm_redis_cache_interval if using the batch mode.'),
          cols: [
            {
              namespace: 'ntlm_cache_expiry',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'ntlm_cache_expiry')
            }
          ]
        },
        {
          label: i18n.t('NTLM cache background job'),
          text: i18n.t('When this is enabled, all users matching the LDAP filter will be inserted in the cache via a background job (maintenance.populate_ntlm_redis_cache_interval controls the interval).'),
          cols: [
            {
              namespace: 'ntlm_cache_batch',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('NTLM cache background job individual fetch'),
          text: i18n.t('Whether or not to fetch users on your AD one by one instead of doing a single batch fetch. This is useful when your AD is loaded or experiencing issues during the sync. Note that this makes the batch job much longer and is about 4 times slower when enabled.'),
          cols: [
            {
              namespace: 'ntlm_cache_batch_one_at_a_time',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('NTLM cache on connection'),
          text: i18n.t('When this is enabled, an async job will cache the NTLM credentials of the user every time he connects.'),
          cols: [
            {
              namespace: 'ntlm_cache_on_connection',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
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
      ...validatorsFromMeta(meta, 'id', 'ID'),
      ...{
        [i18n.t('Role exists.')]: not(and(required, conditional(isNew || isClone), hasDomains, domainExists))
      }
    },
    workgroup: validatorsFromMeta(meta, 'workgroup', i18n.t('Workgroup')),
    dns_name: validatorsFromMeta(meta, 'dns_name', i18n.t('DNS name')),
    server_name: validatorsFromMeta(meta, 'server_name', i18n.t('Server name')),
    sticky_dc: validatorsFromMeta(meta, 'sticky_dc', i18n.t('Sticky DC')),
    ad_server: validatorsFromMeta(meta, 'ad_server', i18n.t('Server')),
    dns_servers: validatorsFromMeta(meta, 'dns_servers', i18n.t('Servers')),
    ou: validatorsFromMeta(meta, 'ou', 'OU'),
    ntlm_cache_source: validatorsFromMeta(meta, 'ntlm_cache_source', i18n.t('Source')),
    ntlm_cache_filter: validatorsFromMeta(meta, 'ntlm_cache_filter', i18n.t('Filter')),
    ntlm_cache_expiry: validatorsFromMeta(meta, 'ntlm_cache_expiry', i18n.t('Expiration'))
  }
}
