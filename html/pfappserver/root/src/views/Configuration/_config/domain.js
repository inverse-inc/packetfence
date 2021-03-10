import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

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
