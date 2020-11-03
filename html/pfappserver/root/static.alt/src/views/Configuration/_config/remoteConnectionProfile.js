/* eslint-disable camelcase */
import router from '@/router'
import store from '@/store'
import i18n from '@/utils/locale'
import pfField from '@/components/pfField'
import pfFieldTypeMatch from '@/components/pfFieldTypeMatch'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormBooleanBuilder from '@/components/pfFormBooleanBuilder'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfTree from '@/components/pfTree'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import { pfLocalesList as localesList } from '@/globals/pfLocales'
import { pfOperators } from '@/globals/pfOperators'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  isMacAddress,
  isPort
} from '@/globals/pfValidators'
import {
  required,
  maxLength
} from 'vuelidate/lib/validators'

export const filters = {
  connection_sub_type: {
    value: 'connection_sub_type',
    text: i18n.t('Connection Sub Type'),
    types: [fieldType.CONNECTION_SUB_TYPE]
  },
  connection_type: {
    value: 'connection_type',
    text: i18n.t('Connection Type'),
    types: [fieldType.CONNECTION_TYPE]
  },
  network: {
    value: 'network',
    text: i18n.t('Network'),
    types: [fieldType.SUBSTRING]
  },
  node_role: {
    value: 'node_role',
    text: i18n.t('Node role'),
    types: [fieldType.ROLE_BY_NAME]
  },
  port: {
    value: 'port',
    text: i18n.t('Port'),
    types: [fieldType.INTEGER],
    validators: {
      match: {
        [i18n.t('Invalid Port Number.')]: isPort
      }
    }
  },
  realm: {
    value: 'realm',
    text: i18n.t('Realm'),
    types: [fieldType.REALM],
    taggable: true,
    tagPlaceholder: i18n.t('Click to add new Realm')
  },
  ssid: {
    value: 'ssid',
    text: i18n.t('SSID'),
    types: [fieldType.SSID],
    taggable: true,
    tagPlaceholder: i18n.t('Click to add new SSID')
  },
  switch: {
    value: 'switch',
    text: i18n.t('Switch'),
    types: [fieldType.SWITCHE]
  },
  switch_group: {
    value: 'switch_group',
    text: i18n.t('Switch Group'),
    types: [fieldType.SWITCH_GROUP]
  },
  switch_mac: {
    value: 'switch_mac',
    text: i18n.t('Switch MAC'),
    types: [fieldType.SUBSTRING],
    validators: {
      match: {
        [i18n.t('Invalid MAC address.')]: isMacAddress
      }
    }
  },
  switch_port: {
    value: 'switch_port',
    text: i18n.t('Switch Port'),
    types: [fieldType.SUBSTRING],
    validators: {
      match: {
        [i18n.t('Invalid Port Number.')]: isPort
      }
    }
  },
  tenant: {
    value: 'tenant',
    text: i18n.t('Tenant'),
    types: [fieldType.TENANT]
  },
  time: {
    value: 'time',
    text: i18n.t('Time period'),
    types: [fieldType.SUBSTRING]
  },
  uri: {
    value: 'uri',
    text: i18n.t('URI'),
    types: [fieldType.SUBSTRING]
  },
  fqdn: {
    value: 'fqdn',
    text: i18n.t('FQDN'),
    types: [fieldType.SUBSTRING]
  },
  vlan: {
    value: 'vlan',
    text: i18n.t('VLAN'),
    types: [fieldType.SUBSTRING]
  }
}

export const columns = [
  {
    key: 'status',
    label: 'Status', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'id',
    label: 'Identifier', // i18n defer
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
    key: 'not_sortable',
    required: true,
    visible: false
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
  },
  {
    value: 'description',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'remote_connection_profile', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/remote_connection_profiles',
      defaultSortKeys: [], // use natural order
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'description', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'remote_connection_profiles' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'description', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

const fieldOperatorsFromMeta = (meta = {}) => {
  const { advanced_filter: { properties: { field: { allowed = [] } = {} } = {} } = {} } = meta
  return allowed.map(allowed => {
    const { text, value, siblings: { value: { allowed_values } = {} } = {} } = allowed
    if (allowed_values) {
      return {
        text,
        value,
        options: allowed_values.sort((a, b) => {
          return a.text.localeCompare(b.text)
        })
      }
    }
    return { text, value }
  }).sort((a, b) => {
    return a.text.localeCompare(b.text)
  })
}

const valueOperatorsFromMeta = (meta = {}) => {
  const { advanced_filter: { properties: { op: { allowed = [] } = {} } = {} } = {} } = meta
  return allowed.filter(allowed => {
    const { requires = [] } = allowed
    return !requires.includes('values')
  }).map(allowed => {
    const { requires = [], value } = allowed
    return { requires, value }
  })
}

const valuesOperatorsFromMeta = (meta = {}) => {
  const { advanced_filter: { properties: { op: { allowed = [] } = {} } = {} } = {} } = meta
  return allowed.filter(allowed => {
    const { requires = [] } = allowed
    return requires.includes('values') || requires.length === 0
  }).map(allowed => {
    const { value } = allowed
    return value
  })
}

export const view = (form = {}, meta = {}) => {
  const {
    id
  } = form
  const {
    isNew = false,
    isClone = false,
    files = [],
    sortFiles = null,
    createDirectory = null,
    deleteFile = null
  } = meta

  // fields differ w/ & wo/ 'default'
  const isDefault = (id === 'default')

  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Remote Profile Name'),
          text: i18n.t('A profile id can only contain alphanumeric characters, dashes, period and or underscores.'),
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
          label: i18n.t('Description'),
          cols: [
            {
              namespace: 'description',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'description')
              }
            }
          ]
        },
        {
          if: !isDefault,
          label: i18n.t('Enable profile'),
          cols: [
            {
              namespace: 'status',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: !isDefault,
          label: i18n.t('Filter on attribute'),
          text: i18n.t('The attribute to filter on'),
          cols: [
            {
              namespace: 'basic_filter_type',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'basic_filter_type')
            }
          ]
        },
        {
          if: !isDefault,
          label: i18n.t('Filter value'),
          cols: [
            {
              namespace: 'basic_filter_value',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'basic_filter_value')
              }
            }
          ]
        },
        {
          label: i18n.t('Allow communication to devices of the same role'),
          cols: [
            {
              namespace: 'allow_communication_same_role',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Allow communication to devices having these roles'),
          cols: [
            {
              namespace: 'allow_communication_to_roles',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'allow_communication_to_roles')
            }
          ]
        },
        {
          label: i18n.t('Resolve hostnames of peers'),
          text: i18n.t('Whether or not the wireguard clients should be able to resolve the DNS names of their peers'),
          cols: [
            {
              namespace: 'resolve_hostnames_of_peers',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Additional domains to resolve'),
          text: i18n.t('List of domains to resolve through PacketFence inside the wireguard network'),
          cols: [
            {
              namespace: 'additional_domains_to_resolve',
              component: pfFormTextarea,
              attrs: attributesFromMeta(meta, 'additional_domains_to_resolve')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    id,
  } = form
  const {
    isNew = false,
    isClone = false
  } = meta

  // fields differ w/ & wo/ 'default'
  const isDefault = (id === 'default')

  return {
    ...{
      id: {
        ...validatorsFromMeta(meta, 'id', i18n.t('Name')),
      },
      description: {
        ...validatorsFromMeta(meta, 'description', i18n.t('Description')),
      },
      status: {
        ...validatorsFromMeta(meta, 'status', i18n.t('Status')),
      },
      basic_filter_type: {
        ...validatorsFromMeta(meta, 'basic_filter_type', i18n.t('Basic filter type')),
      },
      basic_filter_value: {
        ...validatorsFromMeta(meta, 'basic_filter_value', i18n.t('Basic filter value')),
      },
      allow_communication_same_role: {
        ...validatorsFromMeta(meta, 'allow_communication_same_role', i18n.t('Allow communication of devices within the same role')),
      },
      allow_communication_to_roles: {
        ...validatorsFromMeta(meta, 'allow_communication_to_roles', i18n.t('Allow communication to devices having these roles')),
      },
    }
  }
}
