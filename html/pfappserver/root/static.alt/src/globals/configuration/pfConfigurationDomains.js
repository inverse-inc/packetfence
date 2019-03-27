import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
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
  hasDomains,
  domainExists
} from '@/globals/pfValidators'

const {
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationDomainsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  },
  {
    key: 'workgroup',
    label: i18n.t('Workgroup'),
    sortable: true,
    visible: true
  },
  {
    key: 'ntlm_cache',
    label: i18n.t('NTLM Cache'),
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

export const pfConfigurationDomainsListFields = [
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

export const pfConfigurationDomainsListConfig = (context = {}) => {
  return {
    columns: pfConfigurationDomainsListColumns,
    fields: pfConfigurationDomainsListFields,
    rowClickRoute (item, index) {
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

export const pfConfigurationDomainViewFields = (context = {}) => {
  const {
    isNew = false,
    isClone = false,
    options: {
      meta = {}
    }
  } = context
  return [
    {
      tab: i18n.t('Settings'),
      fields: [
        {
          label: i18n.t('Identifier'),
          text: i18n.t(`Specify a unique identifier for your configuration.<br/>This doesn't have to be related to your domain.`),
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
                  [i18n.t('Role exists.')]: not(and(required, conditional(isNew || isClone), hasDomains, domainExists))
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Workgroup'),
          fields: [
            {
              key: 'workgroup',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'workgroup'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'workgroup', 'Workgroup')
            }
          ]
        },
        {
          label: i18n.t('DNS name of the domain'),
          text: i18n.t('The DNS name (FQDN) of the domain.'),
          fields: [
            {
              key: 'dns_name',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'dns_name'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'dns_name', 'DNS name')
            }
          ]
        },
        {
          label: i18n.t(`This server's name`),
          text: i18n.t(`This server's name (account name) in your Active Directory. Use '%h' to automatically use this server hostname.`),
          fields: [
            {
              key: 'server_name',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'server_name'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'server_name', 'Server name')
            }
          ]
        },
        {
          label: i18n.t('Sticky DC'),
          text: i18n.t(`This is used to specify a sticky domain controller to connect to. If not specified, default '*' will be used to connect to any available domain controller.`),
          fields: [
            {
              key: 'sticky_dc',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'sticky_dc'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'sticky_dc', 'Sticky DC')
            }
          ]
        },
        {
          label: i18n.t('Active Directory server'),
          text: i18n.t('The IP address or DNS name of your Active Directory server.'),
          fields: [
            {
              key: 'ad_server',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'ad_server'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'ad_server', 'Server')
            }
          ]
        },
        {
          label: i18n.t('DNS server(s)'),
          text: i18n.t('The IP address(es) of the DNS server(s) for this domain. Comma delimited if multiple.'),
          fields: [
            {
              key: 'dns_servers',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'dns_servers'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'dns_servers', 'DNS server(s)')
            }
          ]
        },
        {
          label: i18n.t('Username'),
          text: i18n.t('The username of a Domain Admin to use to join the server to the domain.'),
          fields: [
            {
              key: 'bind_dn',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'bind_dn'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'bind_dn', 'Username')
            }
          ]
        },
        {
          label: i18n.t('Password'),
          text: i18n.t('The password of a Domain Admin to use to join the server to the domain. Will not be stored permanently and is only used while joining the domain.'),
          fields: [
            {
              key: 'bind_pass',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'bind_pass'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'bind_pass', 'Password')
            }
          ]
        },
        {
          label: i18n.t('OU'),
          text: i18n.t(`Precreate the computer account in a specific OU. The OU string read from top to bottom without RDNs and delimited by a '/'. E.g. "Computers/Servers/Unix".`),
          fields: [
            {
              key: 'ou',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'ou'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'ou', 'OU')
            }
          ]
        },
        {
          label: i18n.t('Allow on registration'),
          text: i18n.t('If this option is enabled, the device will be able to reach the Active Directory from the registration VLAN.'),
          fields: [
            {
              key: 'registration',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: '1', unchecked: '0' }
              }
            }
          ]
        },
        {
          label: null, /* no label */
          fields: [
            {
              component: pfFormHtml,
              attrs: {
                html: `<div class="p-3 bg-warning text-secondary">
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
      fields: [
        {
          label: i18n.t('NTLM cache'),
          text: i18n.t('Should the NTLM cache be enabled for this domain?'),
          fields: [
            {
              key: 'ntlm_cache',
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
          fields: [
            {
              key: 'ntlm_cache_source',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'ntlm_cache_source'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'ntlm_cache_source', 'Source')
            }
          ]
        },
        {
          label: i18n.t('LDAP filter'),
          text: i18n.t('An LDAP query to filter out the users that should be cached.'),
          fields: [
            {
              key: 'ntlm_cache_filter',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'ntlm_cache_filter'),
                ...{
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'ntlm_cache_filter', 'LDAP filter')
            }
          ]
        },
        {
          label: i18n.t('Expiration'),
          text: i18n.t('The amount of seconds an entry should be cached. This should be adjusted to twice the value of maintenance.populate_ntlm_redis_cache_interval if using the batch mode.'),
          fields: [
            {
              key: 'ntlm_cache_expiry',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'ntlm_cache_expiry'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'ntlm_cache_expiry', 'Expiration')
            }
          ]
        },
        {
          label: i18n.t('NTLM cache background job'),
          text: i18n.t('When this is enabled, all users matching the LDAP filter will be inserted in the cache via a background job (maintenance.populate_ntlm_redis_cache_interval controls the interval).'),
          fields: [
            {
              key: 'ntlm_cache_batch',
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
          fields: [
            {
              key: 'ntlm_cache_batch_one_at_a_time',
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
          fields: [
            {
              key: 'ntlm_cache_on_connection',
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
