import i18n from '@/utils/locale'
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
  hasWmiRules,
  wmiRuleExists
} from '@/globals/pfValidators'
import { required } from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: i18n.t('WMI Rule'),
    required: true,
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
    locked: true
  }
]

export const fields = [
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

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
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

export const view = (form, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta

  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('WMI Rule'),
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
          label: i18n.t('On node tab'),
          text: i18n.t('Scan this WMI element while editing a node.'),
          cols: [
            {
              namespace: 'on_tab',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: '1', unchecked: '0' },
                colors: { checked: 'var(--success)', unchecked: 'var(--danger)' }
              }
            }
          ]
        },
        {
          label: i18n.t('Namespace'),
          cols: [
            {
              namespace: 'namespace',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'namespace')
            }
          ]
        },
        {
          label: i18n.t('Request'),
          cols: [
            {
              namespace: 'request',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'request'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Rules Actions'),
          text: i18n.t('Add an action based on the result of the request.'),
          cols: [
            {
              namespace: 'action',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'action'),
                ...{
                  rows: 5
                }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', i18n.t('Rule')),
      ...{
        [i18n.t('WMI Rule exists.')]: not(and(required, conditional(isNew || isClone), hasWmiRules, wmiRuleExists))
      }
    },
    namespace: validatorsFromMeta(meta, 'namespace', i18n.t('Namespace')),
    request: validatorsFromMeta(meta, 'request', i18n.t('Request')),
    action: validatorsFromMeta(meta, 'action', i18n.t('Action'))
  }
}
