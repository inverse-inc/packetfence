import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export const columns = [
  {
    key: 'id',
    label: 'MAC',
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'ip',
    label: 'IP Address', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'pvid',
    label: 'Native VLAN', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'taggedVlan',
    label: `Tagged VLAN's`, // i18n defer
    sortable: false,
    visible: true
  },
  {
    key: 'trunkPort',
    label: 'Trunk Port', // i18n defer
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
    text: i18n.t('MAC'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'ip',
    text: i18n.t('IP Address'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'floating_device', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by MAC or IP address'),
    searchableOptions: {
      searchApiEndpoint: 'config/floating_devices',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'ip', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'floating_devices' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'ip', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}
