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
    key: 'cn',
    label: 'Common Name', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'mail',
    label: 'Email', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'organisation',
    label: 'Organisation', // i18n defer
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
    value: 'cn',
    text: i18n.t('Common Name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'mail',
    text: i18n.t('Email'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'organisation',
    text: i18n.t('Organisation'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'pkiCa', params: { id: item.ID } }
    },
    searchPlaceholder: i18n.t('Search by identifier, common name, email or organisation'),
    searchableOptions: {
      searchApiEndpoint: 'pki/cas',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'cn', op: 'contains', value: null },
            { field: 'mail', op: 'contains', value: null },
            { field: 'organisation', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'pkiCas' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'cn', op: 'contains', value: quickCondition },
              { field: 'mail', op: 'contains', value: quickCondition },
              { field: 'organisation', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}
