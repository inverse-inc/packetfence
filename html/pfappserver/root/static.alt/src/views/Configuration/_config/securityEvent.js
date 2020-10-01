import Vue from 'vue'
import store from '@/store'
import bytes from '@/utils/bytes'
import i18n from '@/utils/locale'
import pfFieldTypeValue from '@/components/pfFieldTypeValue'
import pfFormInput from '@/components/pfFormInput'
import pfFormFields from '@/components/pfFormFields'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormSecurityEventTrigger from '@/components/pfFormSecurityEventTrigger'
import pfFormSecurityEventTriggerHeader from '@/components/pfFormSecurityEventTriggerHeader'
import pfFormSecurityEventActions from '@/components/pfFormSecurityEventActions'
import pfFormSelect from '@/components/pfFormSelect'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasSecurityEvents,
  securityEventExists
} from '@/globals/pfValidators'
import {
  required,
  minValue,
  maxLength
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'enabled',
    label: 'Status', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'id',
    label: 'ID',
    sortable: true,
    visible: true
  },
  {
    key: 'desc',
    label: 'Description', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'priority',
    label: 'Priority',
    sortable: true,
    visible: true
  },
  {
    key: 'template',
    label: 'Template', // i18n defer
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
      return { name: 'security_event', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/security_events',
      defaultSortKeys: [],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'desc', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'security_events' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'desc', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    id = null
  } = form
  const {
    isNew = false,
    isClone = false
  } = meta

  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('Enable security event'),
          cols: [
            {
              namespace: 'enabled',
              component: pfFormRangeToggle,
              attrs: {
                disabled: id === 'defaults',
                values: { checked: 'Y', unchecked: 'N' },
                colors: { checked: 'var(--success)', unchecked: 'var(--danger)' }
              }
            }
          ]
        },
        {
          label: i18n.t('Identifier'),
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
              namespace: 'desc',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'desc')
            }
          ]
        },
        {
          label: i18n.t('Priority'),
          text: i18n.t('When multiple violations are opened for an endpoint, the one with the lowest priority takes precedence.'),
          cols: [
            {
              namespace: 'priority',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'priority')
            }
          ]
        },
        {
          label: i18n.t('Ignored Roles'),
          text: i18n.t(`Which roles shouldn't be impacted by this security event.`),
          cols: [
            {
              namespace: 'whitelisted_roles',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'whitelisted_roles')
            }
          ]
        },
        {
          label: i18n.t('Event Triggers'),
          if: (form.triggers && form.triggers.length),
          cols: [
            {
              component: pfFormSecurityEventTriggerHeader
            }
          ]
        },
        {
          label: ' ',
          cols: [
            {
              namespace: 'triggers',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Trigger'),
                sortable: true,
                field: {
                  component: pfFormSecurityEventTrigger,
                  attrs: { meta }
                },
                invalidFeedback: i18n.t('Trigger(s) contain one or more errors.')
              }
            }
          ]
        },
        {
          label: i18n.t('Event Actions'),
          cols: [
            {
              namespace: '', // use the model itself
              component: pfFormSecurityEventActions,
              attrs: { meta }
            }
          ]
        },
        {
          label: i18n.t('Dynamic Window'),
          text: i18n.t('Only works for accounting security events. The security event will be opened according to the time you set in the accounting security event (ie. You have an accounting security event for 10GB/month. If you bust the bandwidth after 3 days, the security event will open and the release date will be set for the last day of the current month).'),
          cols: [
            {
              namespace: 'window_dynamic',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: '1', unchecked: '0' }
              }
            }
          ]
        },
        {
          label: i18n.t('Grace'),
          text: i18n.t('Amount of time before the security event can reoccur. This is useful to allow hosts time (in the example 2 minutes) to download tools to fix their issue, or shutoff their peer-to-peer application.'),
          cols: [
            {
              namespace: 'grace.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'grace.interval')
            },
            {
              namespace: 'grace.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'grace.unit')
            }
          ]
        },
        {
          label: i18n.t('Window'),
          text: i18n.t('Amount of time before a security event will be closed automatically. Instead of allowing people to reactivate the network, you may want to open a security event for a defined amount of time instead.'),
          cols: [
            {
              namespace: 'window.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'window.interval')
            },
            {
              namespace: 'window.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'window.unit')
            }
          ]
        },
        {
          label: i18n.t('Delay By'),
          text: i18n.t('Delay before triggering the security event.'),
          cols: [
            {
              namespace: 'delay_by.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'delay_by.interval')
            },
            {
              namespace: 'delay_by.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'delay_by.unit')
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
  const {
    triggers = []
  } = form
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', 'ID'),
      ...{
        [i18n.t('Security event exists.')]: not(and(required, conditional(isNew || isClone), hasSecurityEvents, securityEventExists))
      }
    },
    desc: validatorsFromMeta(meta, 'desc', i18n.t('Description')),
    priority: validatorsFromMeta(meta, 'priority', i18n.t('Priority')),
    whitelisted_roles: validatorsFromMeta(meta, 'whitelisted_roles', i18n.t('Roles')),
    grace: {
      interval: validatorsFromMeta(meta, 'grace.interval', i18n.t('Interval')),
      unit: validatorsFromMeta(meta, 'grace.unit', i18n.t('Unit'))
    },
    window: {
      interval: validatorsFromMeta(meta, 'window.interval', i18n.t('Interval')),
      unit: validatorsFromMeta(meta, 'window.unit', i18n.t('Unit'))
    },
    delay_by: {
      interval: validatorsFromMeta(meta, 'delay_by.interval', i18n.t('Interval')),
      unit: validatorsFromMeta(meta, 'delay_by.unit', i18n.t('Unit'))
    },
    triggers: {
      ...(triggers || []).map((trigger) => {
        const {
          endpoint: { conditions: endpointConditions } = {},
          profiling: { conditions: profilingConditions } = {},
          usage: { type: usageType } = {},
          event: {
            typeValue: {
              type: eventType
            } = {}
          } = {}
        } = trigger || {}
        return {
          endpoint: {
            conditions: {
              ...(endpointConditions || []).map(condition => {
                const { type } = condition || {}
                return {
                  type: {
                    [i18n.t('Type required.')]: required,
                    [i18n.t('Duplicate type.')]: conditional(type => endpointConditions.filter(condition => condition && condition.type === type).length <= 1)
                  },
                  value: {
                    ...{
                      [i18n.t('Value required.')]: required
                    },
                    ...((type && 'validators' in triggerFields[type])
                      ? triggerFields[type].validators
                      : {}
                    )
                  }
                }
              })
            }
          },
          profiling: {
            conditions: {
              ...(profilingConditions || []).map(condition => {
                const { type } = condition || {}
                return {
                  type: {
                    [i18n.t('Type required.')]: required,
                    [i18n.t('Duplicate type.')]: conditional(type => profilingConditions.filter(condition => condition && condition.type === type).length <= 1)
                  },
                  value: {
                    ...{
                      [i18n.t('Value required.')]: required
                    },
                    ...((type && 'validators' in triggerFields[type])
                      ? triggerFields[type].validators
                      : {}
                    )
                  }
                }
              })
            }
          },
          usage: {
            ...((usageType === 'bandwidth')
              ? {
                direction: {
                  [i18n.t('Direction required.')]: required
                },
                limit: {
                  [i18n.t('Limit required.')]: required,
                  [i18n.t('Limit must be greater than 0.')]: minValue(0)
                },
                interval: {
                  [i18n.t('Interval required.')]: required
                }
              }
              : {}
            )
          },
          event: {
            typeValue: {
              type: {/* noop */},
              value: {
                ...{
                  [i18n.t('Value required.')]: conditional(() => { // only require 'value' if 'type' is set
                    const { event: { typeValue: { type, value } = {} } = {} } = trigger || {}
                    return ([undefined, null].includes(type) || !([undefined, null, ''].includes(value)))
                  })
                },
                ...((eventType && 'validators' in triggerFields[eventType])
                  ? triggerFields[eventType].validators
                  : {}
                )
              }
            }
          }
        }
      })
    }
  }
}

export const triggerCategories = {
  ENDPOINT: 'endpoint',
  PROFILING: 'profiling',
  USAGE: 'usage',
  EVENT: 'event'
}

export const triggerCategoryTitles = {
  [triggerCategories.ENDPOINT]: i18n.t('Endpoint'),
  [triggerCategories.PROFILING]: i18n.t('Device Profiling'),
  [triggerCategories.USAGE]: i18n.t('Usage'),
  [triggerCategories.EVENT]: i18n.t('Event')
}

export const triggerFields = {
  accounting: {
    text: i18n.t('Accounting'),
    category: triggerCategories.USAGE
  },
  custom: {
    text: i18n.t('Custom'),
    category: triggerCategories.EVENT,
    validators: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    }
  },
  detect: {
    text: i18n.t('Detect'),
    category: triggerCategories.EVENT,
    validators: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    }
  },
  device: {
    text: i18n.t('Device'),
    category: triggerCategories.PROFILING
  },
  dhcp_fingerprint: {
    text: i18n.t('DHCP Fingerprint'),
    category: triggerCategories.PROFILING
  },
  dhcp_vendor: {
    text: i18n.t('DHCP Vendor'),
    category: triggerCategories.PROFILING
  },
  dhcp6_fingerprint: {
    text: i18n.t('DHCPv6 Fingerprint'),
    category: triggerCategories.PROFILING
  },
  dhcp6_enterprise: {
    text: i18n.t('DHCPv6 Enterprise'),
    category: triggerCategories.PROFILING
  },
  internal: {
    text: i18n.t('Internal'),
    category: triggerCategories.EVENT
  },
  mac: {
    text: i18n.t('MAC Address'),
    category: triggerCategories.ENDPOINT
  },
  mac_vendor: {
    text: i18n.t('MAC Vendor'),
    category: triggerCategories.PROFILING
  },
  nessus: {
    text: 'Nessus',
    category: triggerCategories.EVENT
  },
  nessus6: {
    text: 'Nessus v6',
    category: triggerCategories.EVENT
  },
  nexpose_event_contains: {
    text: i18n.t('Nexpose event contains ..'),
    category: triggerCategories.EVENT
  },
  nexpose_event_starts_with: {
    text: i18n.t('Nexpose event starts with ..'),
    category: triggerCategories.EVENT
  },
  openvas: {
    text: 'OpenVAS',
    category: triggerCategories.EVENT
  },
  provisioner: {
    text: i18n.t('Provisioner'),
    category: triggerCategories.EVENT
  },
  role: {
    text: i18n.t('Role'),
    category: triggerCategories.ENDPOINT
  },
  suricata_event: {
    text: i18n.t('Suricata Event'),
    category: triggerCategories.EVENT
  },
  suricata_md5: {
    text: 'Suricata MD5',
    category: triggerCategories.EVENT
  },
  switch: {
    text: i18n.t('Switch'),
    category: triggerCategories.ENDPOINT
  },
  switch_group: {
    text: i18n.t('Switch Group'),
    category: triggerCategories.ENDPOINT
  },
  tenableio: {
    text: i18n.t('Tenable.io'),
    category: triggerCategories.EVENT
  },
}

export const triggerDirections = {
  TOT: i18n.t('Total'),
  IN: i18n.t('Inbound'),
  OUT: i18n.t('Outbound')
}

export const triggerIntervals = {
  D: i18n.t('Day'),
  W: i18n.t('Week'),
  M: i18n.t('Month'),
  Y: i18n.t('Year')
}

export const decomposeTriggers = (triggers) => {
  return (triggers || []).map(trigger => {
    let decomposed = { endpoint: { conditions: [] }, profiling: { conditions: [] }, usage: {}, event: {} }
    for (const type in trigger) {
      const { [type]: value } = trigger
      if (value && value.length) {
        if (type in triggerFields) {
          let { [type]: { category } = {} } = triggerFields
          if ('conditions' in decomposed[category]) {
            decomposed[category].conditions.push({ type, value }) // 'endpoint' or 'profiling'
          } else {
            decomposed[category] = { typeValue: { type, value } } // 'usage' or 'event'
          }
          if (category === triggerCategories.USAGE) {
            if (value === 'BandwidthExpired' || value === 'TimeExpired') {
              decomposed[category].type = value
            } else {
              // Try to decompose data usage
              const { groups = null } = value.match(/(?<direction>TOT|IN|OUT)(?<limit>[0-9]+)(?<multiplier>[KMG]?)B(?<interval>[DWMY])/)
              if (groups) {
                decomposed[category].type = 'bandwidth'
                decomposed[category].direction = groups.direction
                decomposed[category].limit = groups.limit * Math.pow(1024, 'KMG'.indexOf(groups.multiplier) + 1)
                decomposed[category].interval = groups.interval
              }
            }
          } else if (category === triggerCategories.EVENT && type === 'internal') {
            // Extract network behavior policy name
            let match = /(fingerbank_diff_score_too_low|fingerbank_blacklisted_ips_threshold_too_high|fingerbank_blacklisted_ports)_(.+)/.exec(value)
            if (match) {
              decomposed[category].typeValue.value = match[1]
              decomposed[category].fingerbank_network_behavior_policy = match[2]
            } else {
              decomposed[category].fingerbank_network_behavior_policy = 'all'
            }
          }
        } else {
          throw new Error(`Uncategorized field type: ${type}`)
        }
      }
    }
    return decomposed
  })
}

export const recomposeTriggers = (triggers) => {
  return (triggers || []).map(trigger => {
    let recomposed = Object.keys(triggerFields).reduce((a, v) => {
      return { ...a, ...{ [v]: null } }
    }, {})
    for (var category in trigger) {
      if ([triggerCategories.ENDPOINT, triggerCategories.PROFILING].includes(category)) { // 'endpoint' or 'profiling'
        const { [category]: { conditions = [] } = {} } = trigger
        for (const condition of conditions) {
          const { type, value } = condition || {}
          if (type && value) {
            const { value: nestedValue } = value || {}
            if (nestedValue) {
              recomposed[type] = nestedValue
            } else {
              recomposed[type] = value
            }
          }
        }
      }
      if ([triggerCategories.USAGE, triggerCategories.EVENT].includes(category)) { // 'usage' or 'event'
        if (category === triggerCategories.USAGE) { // normalize 'usage'
          const { [category]: { direction, limit, interval, type } = {} } = trigger
          trigger[triggerCategories.USAGE]['typeValue'] = {
            type: 'accounting',
            value: (direction && limit && interval)
              ? `${direction}${bytes.toHuman(limit, 0, true).replace(/ /, '').toUpperCase()}B${interval}`
              : type
          }
        } else if (category === triggerCategories.EVENT) {
          // Append network behavior policy name
          const { [category]: { typeValue: { type, value } = {}, fingerbank_network_behavior_policy } = {} } = trigger
          if (type === 'internal' && fingerbank_network_behavior_policy !== 'all' && ['fingerbank_diff_score_too_low', 'fingerbank_blacklisted_ips_threshold_too_high', 'fingerbank_blacklisted_ports'].includes(value)) {
            trigger[category].typeValue.value += `_${fingerbank_network_behavior_policy}`
          }
        }
        const { [category]: { typeValue: { type, value } = {} } = {} } = trigger
        if (type && value) {
          recomposed[type] = value
        }
      }
    }
    return recomposed
  })
}

export const triggerEndpointView = (form, meta = {}) => {
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          cols: [
            {
              component: pfFormFields,
              namespace: 'conditions',
              attrs: {
                buttonLabel: i18n.t('Add Condition'),
                sortable: false,
                field: {
                  component: pfFieldTypeValue,
                  attrs: {
                    typeLabel: i18n.t('Select type'),
                    valueLabel: i18n.t('Select value'),
                    fields: [
                      {
                        ...attributesFromMeta(meta, 'triggers.role'),
                        ...{
                          value: 'role',
                          text: triggerFields.role.text,
                          types: [fieldType.OPTIONS]
                        }
                      },
                      {
                        value: 'mac',
                        text: triggerFields.mac.text,
                        types: [fieldType.SUBSTRING]
                      },
                      {
                        ...attributesFromMeta(meta, 'triggers.switch'),
                        ...{
                          value: 'switch',
                          text: triggerFields.switch.text,
                          types: [fieldType.OPTIONS]
                        }
                      },
                      {
                        ...attributesFromMeta(meta, 'triggers.switch_group'),
                        ...{
                          value: 'switch_group',
                          text: triggerFields.switch_group.text,
                          types: [fieldType.OPTIONS]
                        }
                      }
                    ]
                  }
                }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const triggerProfilingView = (form, meta = {}) => {
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          cols: [
            {
              component: pfFormFields,
              namespace: 'conditions',
              attrs: {
                buttonLabel: i18n.t('Add Condition'),
                sortable: false,
                field: {
                  component: pfFieldTypeValue,
                  attrs: {
                    typeLabel: i18n.t('Select type'),
                    valueLabel: i18n.t('Select value'),
                    fields: [
                      {
                        attrs: attributesFromMeta(meta, 'triggers.device'),
                        value: 'device',
                        text: triggerFields.device.text,
                        types: [fieldType.OPTIONS]
                      },
                      {
                        attrs: attributesFromMeta(meta, 'triggers.dhcp_fingerprint'),
                        value: 'dhcp_fingerprint',
                        text: triggerFields.dhcp_fingerprint.text,
                        types: [fieldType.OPTIONS]
                      },
                      {
                        attrs: attributesFromMeta(meta, 'triggers.dhcp_vendor'),
                        value: 'dhcp_vendor',
                        text: triggerFields.dhcp_vendor.text,
                        types: [fieldType.OPTIONS]
                      },
                      {
                        attrs: attributesFromMeta(meta, 'triggers.dhcp6_fingerprint'),
                        value: 'dhcp6_fingerprint',
                        text: triggerFields.dhcp6_fingerprint.text,
                        types: [fieldType.OPTIONS]
                      },
                      {
                        attrs: attributesFromMeta(meta, 'triggers.dhcp6_enterprise'),
                        value: 'dhcp6_enterprise',
                        text: triggerFields.dhcp6_enterprise.text,
                        types: [fieldType.OPTIONS]
                      },
                      {
                        attrs: attributesFromMeta(meta, 'triggers.mac_vendor'),
                        value: 'mac_vendor',
                        text: triggerFields.mac_vendor.text,
                        types: [fieldType.OPTIONS]
                      }
                    ]
                  }
                }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const triggerUsageView = (form = {}) => {
  const { [triggerCategories.USAGE]: { type } = {} } = form || {}
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          cols: [
            {
              namespace: 'type',
              component: pfFormSelect,
              attrs: {
                columnLabel: i18n.t('Type'),
                placeholder: i18n.t('Select usage matching type'),
                class: 'w-100',
                options: [
                  { value: 'bandwidth', text: i18n.t('Bandwidth Limit') },
                  { value: 'BandwidthExpired', text: i18n.t('Bandwidth balance has expired') },
                  { value: 'TimeExpired', text: i18n.t('Time balance has expired') }
                ]
              }
            },
            {
              if: type === 'bandwidth',
              namespace: 'direction',
              component: pfFormSelect,
              attrs: {
                columnLabel: i18n.t('Direction'),
                class: 'w-100 mb-1',
                placeholder: i18n.t('Select direction'),
                options: Object.keys(triggerDirections).map(key => ({ value: key, text: triggerDirections[key] }))
              }
            },
            {
              if: type === 'bandwidth',
              namespace: 'limit',
              component: pfFormPrefixMultiplier,
              attrs: {
                columnLabel: i18n.t('Limit'),
                class: 'w-100 mb-1'
              }
            },
            {
              if: type === 'bandwidth',
              namespace: 'interval',
              component: pfFormSelect,
              attrs: {
                columnLabel: i18n.t('Interval'),
                class: 'w-100 mb-1',
                placeholder: i18n.t('Select interval'),
                options: Object.keys(triggerIntervals).map(key => ({ value: key, text: triggerIntervals[key] }))
              }
            }
          ]
        }
      ]
    }
  ]
}

let networkBehaviorPolicies = Vue.observable([{ text: i18n.t('All'), value: 'all' }])

export const triggerEventView = (form, meta = {}) => {
  const { [triggerCategories.EVENT]: { typeValue: { type, value } = {} } = {} } = form || {}

  store.dispatch('$_network_behavior_policies/all').then(policies => {
    policies.map((policy, index) => {
      Vue.set(networkBehaviorPolicies, index + 1, { text: policy.description, value: policy.id })
    })
  })

  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          cols: [
            {
              component: pfFieldTypeValue,
              namespace: 'typeValue',
              attrs: {
                typeLabel: i18n.t('Select trigger type'),
                valueLabel: i18n.t('Select trigger value'),
                fields: [
                  {
                    value: 'custom',
                    text: triggerFields.custom.text,
                    types: [fieldType.SUBSTRING]
                  },
                  {
                    value: 'detect',
                    text: triggerFields.detect.text,
                    types: [fieldType.SUBSTRING]
                  },
                  {
                    ...attributesFromMeta(meta, 'triggers.internal'),
                    ...{
                      value: 'internal',
                      text: triggerFields.internal.text,
                      types: [fieldType.OPTIONS]
                    }
                  },
                  {
                    value: 'nessus',
                    text: triggerFields.nessus.text,
                    types: [fieldType.SUBSTRING]
                  },
                  {
                    value: 'nessus6',
                    text: triggerFields.nessus6.text,
                    types: [fieldType.SUBSTRING]
                  },
                  {
                    value: 'nexpose_event_contains',
                    text: triggerFields.nexpose_event_contains.text,
                    types: [fieldType.SUBSTRING]
                  },
                  {
                    ...attributesFromMeta(meta, 'triggers.nexpose_event_starts_with'),
                    ...{
                      value: 'nexpose_event_starts_with',
                      text: triggerFields.nexpose_event_starts_with.text,
                      types: [fieldType.OPTIONS]
                    }
                  },
                  {
                    value: 'openvas',
                    text: triggerFields.openvas.text,
                    types: [fieldType.SUBSTRING]
                  },
                  {
                    ...attributesFromMeta(meta, 'triggers.provisioner'),
                    ...{
                      value: 'provisioner',
                      text: triggerFields.provisioner.text,
                      types: [fieldType.OPTIONS]
                    }
                  },
                  {
                    ...attributesFromMeta(meta, 'triggers.suricata_event'),
                    ...{
                      value: 'suricata_event',
                      text: triggerFields.suricata_event.text,
                      types: [fieldType.OPTIONS]
                    }
                  },
                  {
                    value: 'suricata_md5',
                    text: triggerFields.suricata_md5.text,
                    types: [fieldType.SUBSTRING]
                  },
                  {
                    value: 'tenableio',
                    text: triggerFields.tenableio.text,
                    types: [fieldType.SUBSTRING]
                  }
                ]
              }
            }
          ]
        },
        {
          cols: [
            {
              if: type === 'internal' && ['fingerbank_diff_score_too_low', 'fingerbank_blacklisted_ips_threshold_too_high', 'fingerbank_blacklisted_ports'].includes(value),
              namespace: 'fingerbank_network_behavior_policy',
              component: pfFormChosen,
              attrs: {
                columnLabel: i18n.t('Policy'),
                class: 'w-100 mb-1',
                options: networkBehaviorPolicies,
                loading: store.getters['$_network_behavior_policies/isLoading']
              }
            }
          ]
        }
      ]
    }
  ]
}
