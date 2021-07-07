import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import makeSearch from '@/store/factory/search'
import api from './_api'

export const useSearch = makeSearch('dhcpOption82Logs', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'mac',
      label: 'MAC Address', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'created_at',
      label: 'Created At', // i18n defer
      searchable: true,
      sortable: true,
      visible: true,
      class: 'text-nowrap',
      formatter: formatter.datetimeIgnoreZero
    },
    {
      key: 'circuit_id_string',
      label: 'Circuit ID String', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'host',
      label: 'Host', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'module',
      label: 'Module', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'option82_switch',
      label: 'Option82 Switch', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'port',
      label: 'Port', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'switch_id',
      label: 'Switch ID', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'vlan',
      label: 'DHCP Option 82 VLAN', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    }
  ],
  fields: [
    {
      value: 'mac',
      text: 'MAC Address', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'created_at',
      text: 'Created', // i18n defer
      types: [conditionType.DATETIME]
    },
    {
      value: 'circuit_id_string',
      text: 'Circuit ID', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'host',
      text: 'Host', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'module',
      text: 'Module', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'option82_switch',
      text: 'Option82 Switch', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'port',
      text: 'Port', // i18n defer
      types: [conditionType.INTEGER]
    },
    {
      value: 'switch_id',
      text: 'Switch ID', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'vlan',
      text: 'VLAN', // i18n defer
      types: [conditionType.INTEGER]
    }
  ],
  sortBy: 'created_at',
  sortDesc: true,
  defaultCondition: () => ({
    op: 'and', values: [
    { op: 'or', values: [
      { field: 'mac', op: 'equals', value: null }
    ] }
  ] })
})
