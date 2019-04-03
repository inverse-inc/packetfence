import i18n from '@/utils/locale'
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
  hasWmiRules,
  wmiRuleExists
} from '@/globals/pfValidators'

const {
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationWmiRulesListColumns = [
  {
    key: 'id',
    label: i18n.t('WMI Rule'),
    sortable: true,
    visible: true
  },
  {
    key: 'namespace',
    label: i18n.t('Namespace'),
    sortable: true,
    visible: true
  },
  {
    key: 'on_tab',
    label: i18n.t('On Node Tab'),
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

export const pfConfigurationWmiRulesListFields = [
  {
    value: 'id',
    text: i18n.t('WMI Rule'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'namespace',
    text: i18n.t('Namespace'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationWmiRuleListConfig = (context = {}) => {
  return {
    columns: pfConfigurationWmiRulesListColumns,
    fields: pfConfigurationWmiRulesListFields,
    rowClickRoute (item, index) {
      return { name: 'wmiRule', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by WMI rule or namespace'),
    searchableOptions: {
      searchApiEndpoint: 'config/wmi_rules',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'namespace', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'wmiRules' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'namespace', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationWmiRuleViewFields = (context = {}) => {
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
          label: i18n.t('WMI Rule'),
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
                ...pfConfigurationValidatorsFromMeta(meta, 'id', 'WMI Rule'),
                ...{
                  [i18n.t('WMI Rule exists.')]: not(and(required, conditional(isNew || isClone), hasWmiRules, wmiRuleExists))
                }
              }
            }
          ]
        },
        {
          label: i18n.t('On node tab'),
          text: i18n.t('Scan this WMI element while editing a node.'),
          fields: [
            {
              key: 'on_tab',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: '1', unchecked: '0' }
              }
            }
          ]
        },
        {
          label: i18n.t('Namespace'),
          fields: [
            {
              key: 'namespace',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'namespace'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'namespace', 'Namespace')
            }
          ]
        },
        {
          label: i18n.t('Request'),
          fields: [
            {
              key: 'request',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'request'),
                ...{
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'request', 'Request')
            }
          ]
        },
        {
          label: i18n.t('Rules Actions'),
          text: i18n.t('Add an action based on the result of the request.'),
          fields: [
            {
              key: 'action',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'action'),
                ...{
                  rows: 5
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'action', 'Action')
            }
          ]
        }
      ]
    }
  ]
}
