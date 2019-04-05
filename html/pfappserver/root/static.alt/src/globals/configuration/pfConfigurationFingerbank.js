import i18n from '@/utils/locale'
import api from '@/views/Configuration/_api'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormHtml from '@/components/pfFormHtml'
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
  isFingerprint,
  isOUI
} from '@/globals/pfValidators'

const {
  integer,
  required,
  minValue,
  maxValue
} = require('vuelidate/lib/validators')

/**
  * This function returns a promise for options based on a search query from within the chosen element.
  * It performs a debounced async API call and builds the options.
  * Initially only the identifier for the current value is provided without a friendly text string
  * The API response is paginated, and available options will be limited to 1 page,
  *  therefore the search results may not contain the current value, subsequently clearing the chosen element.
  * On initialization we will pre-search the current value and cache it for future re-use so that
  *  the returned options will always include the current identifier at the top in order to keep the element from resetting.
**/
export const pfConfigurationFingerbankDeviceOptionsSearchFunction = (query, currentOptions = [], currentValue = null) => {
  const queryTrim = `${query}`.trim() // expect Number or String (1.trim() = exception)
  if (!queryTrim) return []
  const currentOption = currentOptions.find(option => option.value === currentValue) // cache currentValue
  let values = []
  if (queryTrim) values.push({ field: 'id', op: 'equals', value: queryTrim })
  if (currentOption) values.push({ field: 'name', op: 'contains', value: queryTrim }) // subsequent iterations only
  const params = {
    query: { op: 'and', values: [{ op: 'or', values: values }] },
    fields: ['id', 'name'],
    sort: ['name'],
    cursor: 0,
    limit: 100
  }
  return api.fingerbankSearchDevices(params).then(response => {
    return [
      ...((currentOption) ? [currentOption] : []), // include the currentValue in the options to prevent element reset
      ...response.items
        .map(item => { return { value: item.id.toString(), text: item.name } })
        .filter(item => JSON.stringify(item) !== JSON.stringify(currentOption)) // skip duplicates
    ]
  })
}

export const pfConfigurationFingerbankDhcpFingerprintOptionsSearchFunction = (query, currentOptions = [], currentValue = null) => {
  const queryTrim = `${query}`.trim() // expect Number or String (1.trim() = exception)
  if (!queryTrim) return []
  const currentOption = currentOptions.find(option => option.value === currentValue) // cache currentValue
  let values = []
  if (queryTrim) values.push({ field: 'id', op: 'equals', value: queryTrim })
  if (currentOption) values.push({ field: 'value', op: 'contains', value: queryTrim }) // subsequent iterations only
  const params = {
    query: { op: 'and', values: [{ op: 'or', values: values }] },
    fields: ['id', 'value'],
    sort: ['value'],
    cursor: 0,
    limit: 100
  }
  return api.fingerbankSearchDhcpFingerprints(params).then(response => {
    return [
      ...((currentOption) ? [currentOption] : []), // include the currentValue in the options to prevent element reset
      ...response.items
        .map(item => { return { value: item.id.toString(), text: item.value } })
        .filter(item => JSON.stringify(item) !== JSON.stringify(currentOption)) // skip duplicates
    ]
  })
}

export const pfConfigurationFingerbankDhcpv6EnterpriseOptionsSearchFunction = (query, currentOptions = [], currentValue = null) => {
  const queryTrim = `${query}`.trim() // expect Number or String (1.trim() = exception)
  if (!queryTrim) return []
  const currentOption = currentOptions.find(option => option.value === currentValue) // cache currentValue
  let values = []
  if (queryTrim) values.push({ field: 'id', op: 'equals', value: queryTrim })
  if (currentOption) values.push({ field: 'value', op: 'contains', value: queryTrim }) // subsequent iterations only
  const params = {
    query: { op: 'and', values: [{ op: 'or', values: values }] },
    fields: ['id', 'value'],
    sort: ['value'],
    cursor: 0,
    limit: 100
  }
  return api.fingerbankSearchDhcpv6Enterprises(params).then(response => {
    return [
      ...((currentOption) ? [currentOption] : []), // include the currentValue in the options to prevent element reset
      ...response.items
        .map(item => { return { value: item.id.toString(), text: item.value } })
        .filter(item => JSON.stringify(item) !== JSON.stringify(currentOption)) // skip duplicates
    ]
  })
}

export const pfConfigurationFingerbankDhcpv6FingerprintOptionsSearchFunction = (query, currentOptions = [], currentValue = null) => {
  const queryTrim = `${query}`.trim() // expect Number or String (1.trim() = exception)
  if (!queryTrim) return []
  const currentOption = currentOptions.find(option => option.value === currentValue) // cache currentValue
  let values = []
  if (queryTrim) values.push({ field: 'id', op: 'equals', value: queryTrim })
  if (currentOption) values.push({ field: 'value', op: 'contains', value: queryTrim }) // subsequent iterations only
  const params = {
    query: { op: 'and', values: [{ op: 'or', values: values }] },
    fields: ['id', 'value'],
    sort: ['value'],
    cursor: 0,
    limit: 100
  }
  return api.fingerbankSearchDhcpv6Fingerprints(params).then(response => {
    return [
      ...((currentOption) ? [currentOption] : []), // include the currentValue in the options to prevent element reset
      ...response.items
        .map(item => { return { value: item.id.toString(), text: item.value } })
        .filter(item => JSON.stringify(item) !== JSON.stringify(currentOption)) // skip duplicates
    ]
  })
}

export const pfConfigurationFingerbankDhcpVendorOptionsSearchFunction = (query, currentOptions = [], currentValue = null) => {
  const queryTrim = `${query}`.trim() // expect Number or String (1.trim() = exception)
  if (!queryTrim) return []
  const currentOption = currentOptions.find(option => option.value === currentValue) // cache currentValue
  let values = []
  if (queryTrim) values.push({ field: 'id', op: 'equals', value: queryTrim })
  if (currentOption) values.push({ field: 'value', op: 'contains', value: queryTrim }) // subsequent iterations only
  const params = {
    query: { op: 'and', values: [{ op: 'or', values: values }] },
    fields: ['id', 'value'],
    sort: ['value'],
    cursor: 0,
    limit: 100
  }
  return api.fingerbankSearchDhcpVendors(params).then(response => {
    return [
      ...((currentOption) ? [currentOption] : []), // include the currentValue in the options to prevent element reset
      ...response.items
        .map(item => { return { value: item.id.toString(), text: item.value } })
        .filter(item => JSON.stringify(item) !== JSON.stringify(currentOption)) // skip duplicates
    ]
  })
}

export const pfConfigurationFingerbankMacVendorOptionsSearchFunction = (query, currentOptions = [], currentValue = null) => {
  const queryTrim = `${query}`.trim() // expect Number or String (1.trim() = exception)
  if (!queryTrim) return []
  const currentOption = currentOptions.find(option => option.value === currentValue) // cache currentValue
  let values = []
  if (queryTrim) values.push({ field: 'mac', op: 'equals', value: queryTrim })
  if (currentOption) { // subsequent iterations only
    values.push({ field: 'name', op: 'contains', value: queryTrim })
  }
  const params = {
    query: { op: 'and', values: [{ op: 'or', values: values }] },
    fields: ['mac', 'name'],
    sort: ['name'],
    cursor: 0,
    limit: 100
  }
  return api.fingerbankSearchMacVendors(params).then(response => {
    return [
      ...((currentOption) ? [currentOption] : []), // include the currentValue in the options to prevent element reset
      ...response.items
        .map(item => { return { value: item.mac, text: item.name } })
        .filter(item => JSON.stringify(item) !== JSON.stringify(currentOption)) // skip duplicates
    ]
  })
}

export const pfConfigurationFingerbankUserAgentOptionsSearchFunction = (query, currentOptions = [], currentValue = null) => {
  const queryTrim = `${query}`.trim() // expect Number or String (1.trim() = exception)
  if (!queryTrim) return []
  const currentOption = currentOptions.find(option => option.value === currentValue) // cache currentValue
  let values = []
  if (queryTrim) values.push({ field: 'id', op: 'equals', value: queryTrim })
  if (currentOption) values.push({ field: 'value', op: 'contains', value: queryTrim }) // subsequent iterations only
  const params = {
    query: { op: 'and', values: [{ op: 'or', values: values }] },
    fields: ['id', 'value'],
    sort: ['value'],
    cursor: 0,
    limit: 100
  }
  return api.fingerbankSearchUserAgents(params).then(response => {
    return [
      ...((currentOption) ? [currentOption] : []), // include the currentValue in the options to prevent element reset
      ...response.items
        .map(item => { return { value: item.id.toString(), text: item.value } })
        .filter(item => JSON.stringify(item) !== JSON.stringify(currentOption)) // skip duplicates
    ]
  })
}

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
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
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

/**
 * Device Change Detection
**/
export const pfConfigurationFingerbankDeviceChangeDetectionViewFields = (context = {}) => {
  const {
    options: {
      meta = {}
    } = {}
  } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          label: i18n.t('Enabled'),
          text: i18n.t('Whether or not the Fingerbank device change feature is enabled.'),
          fields: [
            {
              key: 'enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Trigger on device class change'),
          text: i18n.t('Whether or not internal::fingerbank_device_change should be triggered when we detect a device class change in Fingerbank.'),
          fields: [
            {
              key: 'trigger_on_device_class_change',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Device class change whitelist'),
          text: i18n.t('Which device class changes are allowed in conjunction with trigger_on_device_class_changeComma delimited transitions using the following format: <code>$PREVIOUS_DEVICE_CLASS_ID->$NEW_DEVICE_CLASS_ID</code> where $PREVIOUS_DEVICE_CLASS_ID and $NEW_DEVICE_CLASS_ID are the IDs in the Fingerbank database.'),
          fields: [
            {
              key: 'device_class_whitelist',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'device_class_whitelist'),
                ...{
                  rows: 5
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'device_class_whitelist', 'Whitelist')
            }
          ]
        },
        {
          label: i18n.t('Manual device class change triggers'),
          text: i18n.t('Which changes (changing from a device class to another) should trigger internal::fingerbank_device_change. This setting is independant from trigger_on_device_class_change and allows to specify exactly which transitions should trigger internal::fingerbank_device_change. Comma delimited transitions using the following format: <code>$PREVIOUS_DEVICE_CLASS_ID->$NEW_DEVICE_CLASS_ID</code> where $PREVIOUS_DEVICE_CLASS_ID and $NEW_DEVICE_CLASS_ID are the IDs in the Fingerbank database.'),
          fields: [
            {
              key: 'device_class_whitelist',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'device_class_whitelist'),
                ...{
                  rows: 5
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'device_class_whitelist', 'Whitelist')
            }
          ]
        },
        {
          label: null,
          fields: [
            {
              component: pfFormHtml,
              attrs: {
                html: `<div class="p-3 bg-warning text-secondary">
                  ${i18n.t('Valid device classes IDs are:')}<br/>
                  <ul>
                    <li><strong>Android OS</strong> = 33453</li>
                    <li><strong>Audio, Imaging or Video Equipment</strong> = 7</li>
                    <li><strong>BlackBerry OS</strong> = 33471</li>
                    <li><strong>Datacenter Appliance</strong> = 23</li>
                    <li><strong>Firewall and Security Appliance</strong> = 33738</li>
                    <li><strong>Gaming Console</strong> = 6</li>
                    <li><strong>Hardware Manufacturer</strong> = 16861</li>
                    <li><strong>Internet of Things (IoT)</strong> = 15</li>
                    <li><strong>iOS</strong> = 33450</li>
                    <li><strong>Linux OS</strong> = 5</li>
                    <li><strong>Mac OS X or macOS</strong> = 2</li>
                    <li><strong>Medical Device</strong> = 8238</li>
                    <li><strong>Monitoring and Testing Device</strong> = 12</li>
                    <li><strong>Network Boot Agent</strong> = 17</li>
                    <li><strong>Operating System</strong> = 16879</li>
                    <li><strong>Phone, Tablet or Wearable</strong> = 11</li>
                    <li><strong>Physical Security</strong> = 22</li>
                    <li><strong>Point of Sale Device</strong> = 24</li>
                    <li><strong>Printer or Scanner</strong> = 8</li>
                    <li><strong>Projector</strong> = 20</li>
                    <li><strong>Robotics and Industrial Automation</strong> = 16842</li>
                    <li><strong>Router, Access Point or Femtocell</strong> = 4</li>
                    <li><strong>Storage Device</strong> = 10</li>
                    <li><strong>Switch and Wireless Controller</strong> = 9</li>
                    <li><strong>Thin Client</strong> = 21</li>
                    <li><strong>Video Conferencing</strong> = 13</li>
                    <li><strong>VoIP Device</strong> = 3</li>
                    <li><strong>Windows OS</strong> = 1</li>
                    <li><strong>Windows Phone OS</strong> = 33507</li>
                  </ul>
                </div>`
              }
            }
          ]
        }
      ]
    }
  ]
}

/**
 * Combinations
 */
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
      return { name: 'fingerbankCombination', params: { scope: scope, id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or device'),
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
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'device_id', op: 'equals', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationFingerbankCombinationViewFields = (context = {}) => {
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
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: pfConfigurationFingerbankDhcpFingerprintOptionsSearchFunction
              }
            }
          ]
        },
        {
          label: i18n.t('DHCP Vendor'),
          fields: [
            {
              key: 'dhcp_vendor_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: pfConfigurationFingerbankDhcpVendorOptionsSearchFunction
              }
            }
          ]
        },
        {
          label: i18n.t('DHCPv6 Fingerprint'),
          fields: [
            {
              key: 'dhcp6_fingerprint_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: pfConfigurationFingerbankDhcpv6FingerprintOptionsSearchFunction
              }
            }
          ]
        },
        {
          label: i18n.t('DHCPv6 Enterprise'),
          fields: [
            {
              key: 'dhcp6_enterprise_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: pfConfigurationFingerbankDhcpv6EnterpriseOptionsSearchFunction
              }
            }
          ]
        },
        {
          label: i18n.t('MAC Vendor (OUI)'),
          fields: [
            {
              key: 'mac_vendor_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: pfConfigurationFingerbankMacVendorOptionsSearchFunction
              }
            }
          ]
        },
        {
          label: i18n.t('User Agent'),
          fields: [
            {
              key: 'user_agent_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: pfConfigurationFingerbankUserAgentOptionsSearchFunction
              }
            }
          ]
        },
        {
          label: i18n.t('Device'),
          fields: [
            {
              key: 'device_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: pfConfigurationFingerbankDeviceOptionsSearchFunction
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

/**
 * Devices
 */
export const pfConfigurationFingerbankDevicesListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  },
  {
    key: 'name',
    label: i18n.t('Device'),
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
    key: 'approved',
    label: i18n.t('Approved'),
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

export const pfConfigurationFingerbankDevicesListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankDevicesListConfig = (context = {}) => {
  const {
    scope = 'all',
    parentId = null
  } = context
  return {
    columns: pfConfigurationFingerbankDevicesListColumns,
    fields: pfConfigurationFingerbankDevicesListFields,
    rowClickRoute (item, index) {
      return { name: 'fingerbankDevice', params: { scope: scope, id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or device'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/${scope}/devices`, // `./search` automatically appended
      searchApiEndpointOnly: true, // always use `/search` endpoint
      defaultSortKeys: ['name'],
      defaultSearchCondition: {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'parent_id', op: 'equals', value: ((parentId) || null) }
            ]
          }
        ]
      },
      defaultRoute: { name: 'fingerbankDevices' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          ...((!quickCondition.trim())
            ? [{ op: 'or', values: [{ field: 'parent_id', op: 'equals', value: ((parentId) || null) }] }]
            : []
          ),
          ...((quickCondition.trim())
            ? [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: quickCondition.trim() },
                { field: 'name', op: 'contains', value: quickCondition.trim() }
              ]
            }]
            : []
          )
        ]
      }
    }
  }
}

export const pfConfigurationFingerbankDeviceViewFields = (context = {}) => {
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
          label: i18n.t('Name'),
          fields: [
            {
              key: 'name',
              component: pfFormInput,
              validators: {
                [i18n.t('Name required.')]: required
              }
            }
          ]
        },
        {
          label: i18n.t('Parent device'),
          fields: [
            {
              key: 'parent_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: pfConfigurationFingerbankDeviceOptionsSearchFunction
              }
            }
          ]
        }
      ]
    }
  ]
}

/**
 * DHCP Fingerprints
 */
export const pfConfigurationFingerbankDhcpFingerprintsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  },
  {
    key: 'value',
    label: i18n.t('DHCP Fingerprint'),
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

export const pfConfigurationFingerbankDhcpFingerprintsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankDhcpFingerprintsListConfig = (context = {}) => {
  const {
    scope
  } = context
  return {
    columns: pfConfigurationFingerbankDhcpFingerprintsListColumns,
    fields: pfConfigurationFingerbankDhcpFingerprintsListFields,
    rowClickRoute (item, index) {
      return { name: 'fingerbankDhcpFingerprint', params: { scope: scope, id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or DHCP fingerprint'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/${scope}/dhcp_fingerprints`,
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
      defaultRoute: { name: 'fingerbankDhcpFingerprints' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'value', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationFingerbankDhcpFingerprintViewFields = (context = {}) => {
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
              key: 'value',
              component: pfFormInput,
              validators: {
                [i18n.t('Fingerprint required.')]: required,
                [i18n.t('Invalid Fingerprint.')]: isFingerprint
              }
            }
          ]
        }
      ]
    }
  ]
}

/**
 * DHCP Vendors
 */
export const pfConfigurationFingerbankDhcpVendorsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  },
  {
    key: 'value',
    label: i18n.t('DHCP Vendor'),
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

export const pfConfigurationFingerbankDhcpVendorsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankDhcpVendorsListConfig = (context = {}) => {
  const {
    scope
  } = context
  return {
    columns: pfConfigurationFingerbankDhcpVendorsListColumns,
    fields: pfConfigurationFingerbankDhcpVendorsListFields,
    rowClickRoute (item, index) {
      return { name: 'fingerbankDhcpVendor', params: { scope: scope, id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or DHCP vendor'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/${scope}/dhcp_vendors`,
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
      defaultRoute: { name: 'fingerbankDhcpVendors' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'value', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationFingerbankDhcpVendorViewFields = (context = {}) => {
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
          label: i18n.t('DHCP Vendor'),
          fields: [
            {
              key: 'value',
              component: pfFormInput,
              validators: {
                [i18n.t('Vendor required.')]: required
              }
            }
          ]
        }
      ]
    }
  ]
}

/**
 * DHCPv6 Fingerprints
 */
export const pfConfigurationFingerbankDhcpv6FingerprintsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  },
  {
    key: 'value',
    label: i18n.t('DHCPv6 Fingerprint'),
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

export const pfConfigurationFingerbankDhcpv6FingerprintsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankDhcpv6FingerprintsListConfig = (context = {}) => {
  const {
    scope
  } = context
  return {
    columns: pfConfigurationFingerbankDhcpv6FingerprintsListColumns,
    fields: pfConfigurationFingerbankDhcpv6FingerprintsListFields,
    rowClickRoute (item, index) {
      return { name: 'fingerbankDhcpv6Fingerprint', params: { scope: scope, id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or DHCPv6 fingerprint'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/${scope}/dhcp6_fingerprints`,
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
      defaultRoute: { name: 'fingerbankDhcpv6Fingerprints' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'value', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationFingerbankDhcpv6FingerprintViewFields = (context = {}) => {
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
          label: i18n.t('DHCPv6 Fingerprint'),
          fields: [
            {
              key: 'value',
              component: pfFormInput,
              validators: {
                [i18n.t('Fingerprint required.')]: required,
                [i18n.t('Invalid Fingerprint.')]: isFingerprint
              }
            }
          ]
        }
      ]
    }
  ]
}

/**
 * DHCPv6 Enterprises
 */
export const pfConfigurationFingerbankDhcpv6EnterprisesListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  },
  {
    key: 'value',
    label: i18n.t('DHCPv6 Enterprise'),
    sortable: true,
    visible: true
  },
  /* TODO - Issue #4217
  {
    key: 'organization',
    label: i18n.t('Organization'),
    sortable: true,
    visible: true
  },
  */
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

export const pfConfigurationFingerbankDhcpv6EnterprisesListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankDhcpv6EnterprisesListConfig = (context = {}) => {
  const {
    scope
  } = context
  return {
    columns: pfConfigurationFingerbankDhcpv6EnterprisesListColumns,
    fields: pfConfigurationFingerbankDhcpv6EnterprisesListFields,
    rowClickRoute (item, index) {
      return { name: 'fingerbankDhcpv6Enterprise', params: { scope: scope, id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or DHCPv6 enterprise'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/${scope}/dhcp6_enterprises`,
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
      defaultRoute: { name: 'fingerbankDhcpv6Enterprises' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'value', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationFingerbankDhcpv6EnterpriseViewFields = (context = {}) => {
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
          label: i18n.t('DHCPv6 Enterprise'),
          fields: [
            {
              key: 'value',
              component: pfFormInput,
              validators: {
                [i18n.t('Enterprise required.')]: required
              }
            }
          ]
        }
      ]
    }
  ]
}

/**
 * MAC Vendors
 */
export const pfConfigurationFingerbankMacVendorsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  },
  {
    key: 'mac',
    label: i18n.t('OUI'),
    sortable: true,
    visible: true
  },
  {
    key: 'name',
    label: i18n.t('MAC Vendor'),
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

export const pfConfigurationFingerbankMacVendorsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankMacVendorsListConfig = (context = {}) => {
  const {
    scope
  } = context
  return {
    columns: pfConfigurationFingerbankMacVendorsListColumns,
    fields: pfConfigurationFingerbankMacVendorsListFields,
    rowClickRoute (item, index) {
      return { name: 'fingerbankMacVendor', params: { scope: scope, id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or MAC vendor'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/${scope}/mac_vendors`,
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
      defaultRoute: { name: 'fingerbankMacVendors' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'mac', op: 'contains', value: quickCondition },
              { field: 'name', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationFingerbankMacVendorViewFields = (context = {}) => {
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
          label: i18n.t('MAC Vendor'),
          fields: [
            {
              key: 'name',
              component: pfFormInput,
              validators: {
                [i18n.t('Vendor required.')]: required
              }
            }
          ]
        },
        {
          label: i18n.t('OUI'),
          text: i18n.t('The OUI is the first six digits or letters of a MAC address. They must be entered without any space or separator (ex: 001122).'),
          fields: [
            {
              key: 'mac',
              component: pfFormInput,
              validators: {
                [i18n.t('OUI required.')]: required,
                [i18n.t('Invalid OUI.')]: isOUI
              }
            }
          ]
        }
      ]
    }
  ]
}

/**
 * User Agents
 */
export const pfConfigurationFingerbankUserAgentsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    sortable: true,
    visible: true
  },
  {
    key: 'value',
    label: i18n.t('User Agent'),
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

export const pfConfigurationFingerbankUserAgentsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationFingerbankUserAgentsListConfig = (context = {}) => {
  const {
    scope
  } = context
  return {
    columns: pfConfigurationFingerbankUserAgentsListColumns,
    fields: pfConfigurationFingerbankUserAgentsListFields,
    rowClickRoute (item, index) {
      return { name: 'fingerbankUserAgent', params: { scope: scope, id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or user agent'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/${scope}/user_agents`,
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
      defaultRoute: { name: 'fingerbankUserAgents' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'value', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationFingerbankUserAgentViewFields = (context = {}) => {
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
          label: i18n.t('User Agent'),
          fields: [
            {
              key: 'value',
              component: pfFormInput,
              validators: {
                [i18n.t('Agent required.')]: required
              }
            }
          ]
        }
      ]
    }
  ]
}
