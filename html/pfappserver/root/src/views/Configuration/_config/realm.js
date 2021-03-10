import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export const columns = [
  {
    key: 'id',
    label: 'Name', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'regex',
    label: 'Regex Realm', // i18n defer
    visible: true
  },
  {
    key: 'eap',
    label: 'eap configuration',
    visible: true
  },
  {
    key: 'domain',
    label: 'Domain', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'radius_auth',
    label: 'RADIUS Authentication', // i18n defer
    visible: true
  },
  {
    key: 'radius_acct',
    label: 'RADIUS Accounting', // i18n defer
    visible: true
  },
  {
    key: 'portal_strip_username',
    label: 'Strip Portal', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'admin_strip_username',
    label: 'Strip Admin', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'radius_strip_username',
    label: 'Strip RADIUS', // i18n defer
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
      return { name: 'realm', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by name'),
    searchableOptions: {
      searchApiEndpoint: 'config/realms',
      defaultSortKeys: [], // use natural ordering
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'realms' }
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
