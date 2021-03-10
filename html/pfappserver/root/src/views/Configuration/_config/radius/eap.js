import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export const columns = [
  {
    key: 'id',
    label: 'Identifier', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'default_eap_type',
    label: 'Default EAP', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'tls_tlsprofile',
    label: 'TLS Profile', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'ttls_tlsprofile',
    label: 'TTLS Profile', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'peap_tlsprofile',
    label: 'PEAP Profile', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'fast_config',
    label: 'Fast Profile', // i18n defer
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

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'radiusEap', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier'),
    searchableOptions: {
      searchApiEndpoint: 'config/radiusd/eap_profiles',
      defaultSortKeys: ['id', 'not_deletable'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'radiusEaps' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}
