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
    key: 'name',
    label: 'Device', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'created_at',
    label: 'Created', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'updated_at',
    label: 'Updated', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'approved',
    label: 'Approved', // i18n defer
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
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = (context = {}) => {
  const {
    scope = 'all',
    parentId = null
  } = context
  return {
    columns,
    fields,
    rowClickRoute (item) {
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
              { field: 'parent_id', op: 'equals', value: (parentId || null) }
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
            ? [{ op: 'or', values: [{ field: 'parent_id', op: 'equals', value: (parentId || null) }] }]
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
