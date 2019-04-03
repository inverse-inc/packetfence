import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormToggle from '@/components/pfFormToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  isHex,
  isFingerprint,
  isFingerbankDevice,
  isOUI
} from '@/globals/pfValidators'

const {
  integer,
  required,
  maxLength,
  minValue,
  maxValue
} = require('vuelidate/lib/validators')

/**
 * General Settings
**/
export const pfConfigurationFingerbankGeneralSettingsViewFields = (context = {}) => {
  const {
    options: {
      meta = {}
    }
  } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          label: i18n.t('API Key'),
          text: i18n.t('API key to interact with upstream Fingerbank project. Changing this value requires to restart the Fingerbank collector.'),
          fields: [
            {
              key: 'upstream.api_key',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'upstream.api_key'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'upstream.api_key', 'Key')
            }
          ]
        },
        {
          label: i18n.t('Upstream API host'),
          text: i18n.t('The host on which the Fingerbank API should be reached.'),
          fields: [
            {
              key: 'upstream.host',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'upstream.host'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'upstream.host', 'Host')
            }
          ]
        },
        {
          label: i18n.t('Upstream API port'),
          text: i18n.t('The port on which the Fingerbank API should be reached.'),
          fields: [
            {
              key: 'upstream.port',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'upstream.port'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'upstream.port', 'Port')
            }
          ]
        },
        {
          label: i18n.t('Upstream API HTTPS'),
          text: i18n.t('Whether or not HTTPS should be used to communicate with the Fingerbank API.'),
          fields: [
            {
              key: 'upstream.use_https',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Database API path'),
          text: i18n.t('Path used to fetch the database on the Fingerbank API.'),
          fields: [
            {
              key: 'upstream.db_path',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'upstream.db_path'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'upstream.db_path', 'Path')
            }
          ]
        },
        {
          label: i18n.t('Retention of the upstream sqlite DB'),
          text: i18n.t('Amount of upstream databases to retain on disk in db/. Should be at least one in case any running processes are still pointing on the old file descriptor of the database.'),
          fields: [
            {
              key: 'upstream.sqlite_db_retention',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'upstream.sqlite_db_retention'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'upstream.sqlite_db_retention', 'Amount')
            }
          ]
        },
        {
          label: i18n.t('Collector host'),
          text: i18n.t('The host on which the Fingerbank collector should be reached.'),
          fields: [
            {
              key: 'collector.host',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'collector.host'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'collector.host', 'Host')
            }
          ]
        },
        {
          label: i18n.t('Collector port'),
          text: i18n.t('The port on which the Fingerbank collector should be reached.'),
          fields: [
            {
              key: 'collector.port',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'collector.port'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'collector.port', 'Port')
            }
          ]
        },
        {
          label: i18n.t('Collector HTTPS'),
          text: i18n.t('Whether or not HTTPS should be used to communicate with the collector.'),
          fields: [
            {
              key: 'collector.use_https',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Inactive endpoints expiration'),
          text: i18n.t('Amount of hours after which the information inactive endpoints should be removed from the collector.'),
          fields: [
            {
              key: 'collector.inactive_endpoints_expiration',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'collector.inactive_endpoints_expiration'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'collector.inactive_endpoints_expiration', 'Hours')
            }
          ]
        },
        {
          label: i18n.t('ARP lookups by the collector'),
          text: i18n.t(`Whether or not the collector should perform ARP lookups for devices it doesn't have DHCP information.`),
          fields: [
            {
              key: 'collector.arp_lookup',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Query cache time in the collector'),
          text: i18n.t('Amount of minutes for which the collector API query results are cached.'),
          fields: [
            {
              key: 'collector.query_cache_time',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'collector.query_cache_time'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'collector.query_cache_time', 'Time')
            }
          ]
        },
        {
          label: i18n.t('Database persistence interval'),
          text: i18n.t('Interval in seconds at which the collector will persist its databases.'),
          fields: [
            {
              key: 'collector.db_persistence_interval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'collector.db_persistence_interval'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'collector.db_persistence_interval', 'Interval')
            }
          ]
        },
        {
          label: i18n.t('Cluster resync interval'),
          text: i18n.t('Interval in seconds at which the collector will fully resynchronize with its peers when in cluster mode. The collector synchronizes in real-time, so this only acts as a safety net when there is a communication error between the collectors.'),
          fields: [
            {
              key: 'collector.cluster_resync_interval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'collector.cluster_resync_interval'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'collector.cluster_resync_interval', 'Interval')
            }
          ]
        },
        {
          label: i18n.t('Record Unmatched Parameters'),
          text: i18n.t('Should the local instance of Fingerbank record unmatched parameters so that it will be possible to submit thoses unmatched parameters to the upstream Fingerbank project for contribution.'),
          fields: [
            {
              key: 'query.record_unmatched',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Use proxy'),
          text: i18n.t('Should Fingerbank interact with WWW using a proxy?'),
          fields: [
            {
              key: 'proxy.use_proxy',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Proxy Host'),
          text: i18n.t('Host the proxy is listening on. Only the host must be specified here without any port or protocol.'),
          fields: [
            {
              key: 'proxy.host',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'proxy.host'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'proxy.host', 'Host')
            }
          ]
        },
        {
          label: i18n.t('Proxy Port'),
          text: i18n.t('Port the proxy is listening on.'),
          fields: [
            {
              key: 'proxy.port',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'proxy.port'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'proxy.port', 'Port')
            }
          ]
        },
        {
          label: i18n.t('Verify SSL'),
          text: i18n.t('Whether or not to verify SSL when using proxying.'),
          fields: [
            {
              key: 'proxy.verify_ssl',
              component: pfFormToggle,
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

export const pfConfigurationFingerbankGeneralSettingsViewDefaults = (context = {}) => {
  return {
    upstream: {
      host: 'api.fingerbank.org',
      port: 443,
      use_https: 'enabled',
      db_path: '/api/v2/download/db',
      sqlite_db_retention: 2
    },
    collector: {
      host: '127.0.0.1',
      port: 4723,
      use_https: 'enabled',
      inactive_endpoints_expiration: 168,
      query_cache_time: 1440,
      db_persistence_interval: 60,
      cluster_resync_interval: 120
    },
    proxy: {
      verify_ssl: 'enabled'
    }
  }
}

/**
 * Device Change Detection
**/
export const pfConfigurationFingerbankDeviceChangeDetectionViewFields = (context = {}) => {
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          label: i18n.t('API Key'),
          text: i18n.t('API key to interact with upstream Fingerbank project. Changing this value requires to restart the Fingerbank collector.'),
          fields: [
            {
              key: 'upstream.api_key',
              component: pfFormInput,
              validators: {
                [i18n.t('Key required.')]: required,
                [i18n.t('Invalid Key.')]: and(maxLength(255), isHex)
              }
            }
          ]
        }
      ]
    }
  ]
}

export const pfConfigurationFingerbankDeviceChangeDetectionViewDefaults = (context = {}) => {
  return {}
}

export const pfConfigurationFingerbankCombinationsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  },
  {
    key: 'device_id',
    label: i18n.t('Device'),
    sortable: true,
    visible: true
  },
  {
    key: 'score',
    label: i18n.t('Score'),
    sortable: true,
    visible: true
  },
  {
    key: 'created_at',
    label: i18n.t('Created'),
    sortable: true,
    visible: true
  },
  {
    key: 'updated_at',
    label: i18n.t('Updated'),
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

export const pfConfigurationFingerbankCombinationsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankCombinationsListConfig = (context = {}) => {
  const {
    scope
  } = context
  return {
    columns: pfConfigurationFingerbankCombinationsListColumns,
    fields: pfConfigurationFingerbankCombinationsListFields,
    rowClickRoute (item, index) {
      return { name: 'fingerbankCombination', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/${scope}/combinations`,
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
      defaultRoute: { name: 'fingerbankCombinations' }
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

export const pfConfigurationFingerbankCombinationsViewFields = (context = {}) => {
  const {
    isNew = false,
    isClone = false
  } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          if: (!isNew && !isClone),
          label: i18n.t('Identifier'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: true
              }
            }
          ]
        },
        {
          label: i18n.t('DHCP Fingerprint'),
          fields: [
            {
              key: 'dhcp_fingerprint_id',
              component: pfFormInput,
              validators: {
                [i18n.t('Invalid Fingerprint.')]: isFingerprint
              }
            }
          ]
        },
        {
          label: i18n.t('DHCP Vendor'),
          fields: [
            {
              key: 'dhcp_vendor_id',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Integers only.')]: integer
              }
            }
          ]
        },
        {
          label: i18n.t('DHCPv6 Fingerprint'),
          fields: [
            {
              key: 'dhcp6_fingerprint_id',
              component: pfFormInput,
              validators: {
                [i18n.t('Invalid Fingerprint.')]: isFingerprint
              }
            }
          ]
        },
        {
          label: i18n.t('DHCPv6 Enterprise'),
          fields: [
            {
              key: 'dhcp6_enterprise_id',
              component: pfFormInput,
              validators: {
                [i18n.t('Integers only.')]: integer
              }
            }
          ]
        },
        {
          label: i18n.t('MAC Vendor (OUI)'),
          fields: [
            {
              key: 'mac_vendor_id',
              component: pfFormInput,
              validators: {
                [i18n.t('Invalid OUI.')]: isOUI('')
              }
            }
          ]
        },
        {
          label: i18n.t('User Agent'),
          fields: [
            {
              key: 'user_agent_id',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Integers only.')]: integer
              }
            }
          ]
        },
        {
          label: i18n.t('Device'),
          fields: [
            {
              key: 'device_id',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Device required.')]: required,
                [i18n.t('Invalid Device.')]: isFingerbankDevice
              }
            }
          ]
        },
        {
          label: i18n.t('Version'),
          fields: [
            {
              key: 'version',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Integers only.')]: integer
              }
            }
          ]
        },
        {
          label: i18n.t('Score'),
          fields: [
            {
              key: 'score',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Score required.')]: required,
                [i18n.t('Integers only.')]: integer,
                [i18n.t('Invalid Score.')]: and(minValue(0), maxValue(100))
              }
            }
          ]
        }
      ]
    }
  ]
}

export const pfConfigurationFingerbankDevicesListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  }
]

export const pfConfigurationFingerbankDevicesListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankDevicesListConfig = (context = {}) => {
  return {
    columns: pfConfigurationFingerbankDevicesListColumns,
    fields: pfConfigurationFingerbankDevicesListFields,
    rowClickRoute (item, index) {
      return { name: 'device', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/TODO',
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
      defaultRoute: { name: 'profilingDevices' }
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

export const pfConfigurationFingerbankDhcpFingerprintsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  }
]

export const pfConfigurationFingerbankDhcpFingerprintsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankDhcpFingerprintsListConfig = (context = {}) => {
  return {
    columns: pfConfigurationFingerbankDhcpFingerprintsListColumns,
    fields: pfConfigurationFingerbankDhcpFingerprintsListFields,
    rowClickRoute (item, index) {
      return { name: 'dhcpFingerprint', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/TODO',
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
      defaultRoute: { name: 'profilingDhcpFingerprints' }
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

export const pfConfigurationFingerbankDhcpVendorsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  }
]

export const pfConfigurationFingerbankDhcpVendorsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankDhcpVendorsListConfig = (context = {}) => {
  return {
    columns: pfConfigurationFingerbankDhcpVendorsListColumns,
    fields: pfConfigurationFingerbankDhcpVendorsListFields,
    rowClickRoute (item, index) {
      return { name: 'dhcpVendor', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/TODO',
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
      defaultRoute: { name: 'profilingDhcpVendors' }
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

export const pfConfigurationFingerbankDhcpv6FingerprintsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  }
]

export const pfConfigurationFingerbankDhcpv6FingerprintsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankDhcpv6FingerprintsListConfig = (context = {}) => {
  return {
    columns: pfConfigurationFingerbankDhcpv6FingerprintsListColumns,
    fields: pfConfigurationFingerbankDhcpv6FingerprintsListFields,
    rowClickRoute (item, index) {
      return { name: 'dhcpv6Fingerprint', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/TODO',
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
      defaultRoute: { name: 'profilingDhcpv6Fingerprints' }
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

export const pfConfigurationFingerbankDhcpv6EnterprisesListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  }
]

export const pfConfigurationFingerbankDhcpv6EnterprisesListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankDhcpv6EnterprisesListConfig = (context = {}) => {
  return {
    columns: pfConfigurationFingerbankDhcpv6EnterprisesListColumns,
    fields: pfConfigurationFingerbankDhcpv6EnterprisesListFields,
    rowClickRoute (item, index) {
      return { name: 'dhcpv6Enterprise', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/TODO',
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
      defaultRoute: { name: 'profilingDhcpv6Enterprises' }
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

export const pfConfigurationFingerbankMacVendorsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  }
]

export const pfConfigurationFingerbankMacVendorsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankMacVendorsListConfig = (context = {}) => {
  return {
    columns: pfConfigurationFingerbankMacVendorsListColumns,
    fields: pfConfigurationFingerbankMacVendorsListFields,
    rowClickRoute (item, index) {
      return { name: 'macVendor', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/TODO',
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
      defaultRoute: { name: 'profilingMacVendors' }
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

export const pfConfigurationFingerbankUserAgentsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  }
]

export const pfConfigurationFingerbankUserAgentsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankUserAgentsListConfig = (context = {}) => {
  return {
    columns: pfConfigurationFingerbankUserAgentsListColumns,
    fields: pfConfigurationFingerbankUserAgentsListFields,
    rowClickRoute (item, index) {
      return { name: 'userAgent', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/TODO',
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
      defaultRoute: { name: 'profilingUserAgents' }
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
