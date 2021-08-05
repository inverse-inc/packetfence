import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import makeSearch from '@/store/factory/search'
import api from './_api'

export const useSearch = makeSearch('dnsLogs', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'id',
      label: 'Log ID', // i18n defer
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'created_at',
      label: 'Created At', // i18n defer
      searchable: true,
      sortable: true,
      visible: true,
      formatter: formatter.datetimeIgnoreZero
    },
    {
      key: 'ip',
      label: 'IP Address', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'mac',
      label: 'MAC Address', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'qname',
      label: 'Qname', // i18n defer
      searchable: true,
      sortable: false,
      visible: true
    },
    {
      key: 'qtype',
      searchable: true,
      label: 'Qtype', // i18n defer
      sortable: false
    },
    {
      key: 'scope',
      label: 'Scope', // i18n defer
      searchable: true,
      sortable: false
    },
    {
      key: 'answer',
      label: 'Answer', // i18n defer
      searchable: true,
      sortable: false,
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
      value: 'id',
      text: 'Log ID', // i18n defer
      types: [conditionType.INTEGER]
    },
    {
      value: 'created_at',
      text: 'Created', // i18n defer
      types: [conditionType.DATETIME]
    },
    {
      value: 'ip',
      text: 'IP Address', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'mac',
      text: 'MAC Address', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'qname',
      text: 'DNS Request', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'qtype',
      text: 'DNS Type', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'scope',
      text: 'Scope', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'answer',
      text: 'DNS Answer', // i18n defer
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'created_at',
  sortDesc: true,
  defaultCondition: () => ({
    op: 'and', values: [
    { op: 'or', values: [
      { field: 'id', op: 'equals', value: null }
    ] }
  ] })
})
