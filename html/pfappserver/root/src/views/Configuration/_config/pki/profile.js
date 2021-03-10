import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export const columns = [
  {
    key: 'ID',
    label: 'Identifier', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'ca_id',
    required: true
  },
  {
    key: 'ca_name',
    label: 'Certificate Authority', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'name',
    label: 'Name', // i18n defer
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
    value: 'ID',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'ca_name',
    text: i18n.t('Certificate Authority'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'name',
    text: i18n.t('Name'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'pkiProfile', params: { id: item.ID } }
    },
    searchPlaceholder: i18n.t('Search by identifier, certificate authority or name'),
    searchableOptions: {
      searchApiEndpoint: 'pki/profiles',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'ca_name', op: 'contains', value: null },
            { field: 'name', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'pkiProfiles' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'ca_name', op: 'contains', value: quickCondition },
              { field: 'name', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}
