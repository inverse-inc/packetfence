import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import makeSearch from '@/store/factory/search'
import api from './_api'

export const useSearch = makeSearch('adminApiLogs', {
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
      class: 'text-nowrap',
      formatter: formatter.datetimeIgnoreZero
    },
    {
      key: 'user_name',
      label: 'User Name', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'action',
      label: 'Action', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'object_id',
      label: 'Object ID', // i18n defer
      searchable: true,
      sortable: false,
      visible: true
    },
    {
      key: 'url',
      label: 'URL', // i18n defer
      searchable: true,
      sortable: false
    },
    {
      key: 'method',
      label: 'Method', // i18n defer
      searchable: true,
      sortable: false
    },
    {
      key: 'status',
      label: 'Status', // i18n defer
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
      value: 'user_name',
      text: 'User Name', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'action',
      text: 'Action', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'object_id',
      text: 'Object ID', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'url',
      text: 'URL', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'method',
      text: 'Scope', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'status',
      text: 'Status', // i18n defer
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
