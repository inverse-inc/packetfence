import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export const columns = [
  {
    key: 'id',
    label: 'WMI Rule', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'namespace',
    label: 'Namespace', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'on_tab',
    label: 'On Node Tab', // i18n defer
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
