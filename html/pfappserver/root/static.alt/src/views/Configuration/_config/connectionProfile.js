import router from '@/router'
import store from '@/store'
import i18n from '@/utils/locale'
import pfField from '@/components/pfField'
import pfFieldTypeMatch from '@/components/pfFieldTypeMatch'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormBooleanBuilder from '@/components/pfFormBooleanBuilder'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
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
  hasConnectionProfiles,
  connectionProfileExists,
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
      return { name: 'connection_profile', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/connection_profiles',
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
      defaultRoute: { name: 'connection_profiles' }
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

export const validators = (form = {}, meta = {}) => {
  const {
    id,
    filter = [],
    advanced_filter,
    sources = [],
    billing_tiers = [],
    provisioners = [],
    scans = [],
    locale = []
  } = form
  const {
    isNew = false,
    isClone = false
  } = meta

  // fields differ w/ & wo/ 'default'
  const isDefault = (id === 'default')

  const requiresFieldsAssociated = {} /*valueOperatorsFromMeta(meta).reduce((associated, item) => {
      const { value, requires } = item
      associated[value] = requires
      return associated
    }, {})*/

  const advancedFilterValidator = (meta = {}, advanced_filter = {}, level = 0) => {
    const { op, values } = advanced_filter
    if (values && values.constructor === Array) { // op
      return {
        op: {
          ...{
            [i18n.t('Operator required.')]: required
          },
          ...((level > 0) // require 2 values when not @ root condition
            ? {
              [i18n.t('Minimum 2 values required.')]: conditional(values.length >= 2)
            }
            : {}
          )
        },
        values: {
          ...(values || []).map(value => advancedFilterValidator(meta, value, ++level))
        }
      }
    } else { // value
      const { [op]: requires = [] } = requiresFieldsAssociated
      const showField = (!op || requires.includes('field'))
      const showValue = (!op || requires.includes('value'))
      return {
        field: {
          ...((showField)
            ? { [i18n.t('Field required.')]: required }
            : {}
          )
        },
        op: {
          [i18n.t('Operator required.')]: required
        },
        value: {
          ...((showValue)
            ? { [i18n.t('Value required.')]: required }
            : {}
          )
        }
      }
    }
  }

  return {
    ...((isDefault)
      ? {} // isDefault
      : { // !isDefault
        filter: {
          ...{
            [i18n.t('Filter or advanced filter required.')]: not(and(conditional(!filter || filter.length === 0), conditional(!advanced_filter)))
          },
          ...(filter || []).map(_filter => { // index based filter validators
            if (_filter) {
              const { type } = _filter
              if (type) {
                const { [type]: { validators: { match: matchValidators = {} } = {} } = {} } = filters
                if (validators) {
                  return {
                    match: {
                      ...{
                        [i18n.t('Match required.')]: required,
                        [i18n.t('Maximum 255 characters.')]: maxLength(255)
                      },
                      ...matchValidators
                    }
                  }
                }
              }
            }
            return {
              type: {
                [i18n.t('Type required.')]: required
              }
            }
          })
        },
        advanced_filter: advancedFilterValidator(meta, advanced_filter)
      }
    ),
    ...{
      id: {
        ...validatorsFromMeta(meta, 'id', i18n.t('Name')),
        ...{
          [i18n.t('Connection Profile exists.')]: not(and(required, conditional(isNew || isClone), hasConnectionProfiles, connectionProfileExists))
        }
      },
      description: validatorsFromMeta(meta, 'description', i18n.t('Description')),
      root_module: validatorsFromMeta(meta, 'root_module', i18n.t('Module')),
      default_psk_key: validatorsFromMeta(meta, 'default_psk_key', i18n.t('Key')),
      vlan_pool_technique: validatorsFromMeta(meta, 'vlan_pool_technique', i18n.t('Algorithm')),
      filter_match_style: validatorsFromMeta(meta, 'filter_match_style', i18n.t('Filters')),
      sources: {
        ...validatorsFromMeta(meta, 'sources', i18n.t('Sources')),
        ...{
          $each: {
            [i18n.t('Source required.')]: required,
            [i18n.t('Duplicate source.')]: conditional((value) => sources.filter(v => v === value).length <= 1)
          }
        }
      },
      billing_tiers: {
        ...validatorsFromMeta(meta, 'billing_tiers', i18n.t('Billing tier')),
        ...{
          $each: {
            [i18n.t('Billing tier required.')]: required,
            [i18n.t('Duplicate billing tier.')]: conditional((value) => billing_tiers.filter(v => v === value).length <= 1)
          }
        }
      },
      provisioners: {
        ...validatorsFromMeta(meta, 'provisioners', i18n.t('Provisioner')),
        ...{
          $each: {
            [i18n.t('Provisioner required.')]: required,
            [i18n.t('Duplicate provisioner.')]: conditional((value) => provisioners.filter(v => v === value).length <= 1)
          }
        }
      },
      scans: {
        ...validatorsFromMeta(meta, 'scans', i18n.t('Scans')),
        ...{
          $each: {
            [i18n.t('Scan required.')]: required,
            [i18n.t('Duplicate scan.')]: conditional((value) => scans.filter(v => v === value).length <= 1)
          }
        }
      },
      self_service: validatorsFromMeta(meta, 'self_service', i18n.t('Registration')),
      logo: validatorsFromMeta(meta, 'logo', i18n.t('Logo')),
      redirecturl: validatorsFromMeta(meta, 'redirecturl', i18n.t('Redirect')),
      block_interval: {
        interval: validatorsFromMeta(meta, 'block_interval.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'block_interval.unit', i18n.t('Unit'))
      },
      sms_pin_retry_limit: validatorsFromMeta(meta, 'sms_pin_retry_limit', i18n.t('Limit')),
      sms_request_limit: validatorsFromMeta(meta, 'sms_request_limit', i18n.t('Limit')),
      login_attempt_limit: validatorsFromMeta(meta, 'login_attempt_limit', i18n.t('Limit')),
      locale: {
        $each: {
          [i18n.t('Locale required.')]: required,
          [i18n.t('Duplicate locale.')]: conditional((value) => locale.filter(v => v === value).length <= 1)
        }
      }
    }
  }
}
