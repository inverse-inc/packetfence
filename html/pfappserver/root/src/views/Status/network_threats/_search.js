import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from './_api'

export const useSearch = makeSearch('networkThreats', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'id',
      label: 'ID', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'status',
      label: 'Status', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'mac',
      label: 'MAC', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'security_event_id',
      label: 'Security Event',
      sortable: true,
      visible: true
    },
    {
      key: 'start_date',
      label: 'Start Date', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'release_date',
      label: 'Release Date', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'ticket_ref',
      label: 'Ticket Ref', // i18n defer
      searchable: true,
      sortable: true,
      visible: false
    },
    {
      key: 'notes',
      label: 'Notes', // i18n defer
      searchable: true,
      sortable: true,
      visible: false
    },
    {
      key: 'node.device_class',
      label: 'Device Category', // i18n defer
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
      value: 'id',
      text: 'Name', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'mac',
      text: 'MAC Address', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'start_date',
      text: 'Start Date', // i18n defer
      types: [conditionType.DATETIME]
    },
    {
      value: 'release_date',
      text: 'Release Date', // i18n defer
      types: [conditionType.DATETIME]
    },
    {
      value: 'ticket_ref',
      text: 'Ticket Ref', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'notes',
      text: 'Notes', // i18n defer
      types: [conditionType.SUBSTRING]
    },
  ],
  sortBy: 'id',
  sortDesc: true
})
