import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

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
