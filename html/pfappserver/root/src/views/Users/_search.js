import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import makeSearch from '@/store/factory/search'
import api from './_api'

export const useSearch = makeSearch('users', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'tenant_id',
      label: 'Tenant', // i18n defer
      searchable: true,
      sortable: true,
      formatter: formatter.tenantId
    },
    {
      key: 'pid',
      label: 'Username', // i18n defer
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'title',
      label: 'Title', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'firstname',
      label: 'Firstname', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'lastname',
      label: 'Lastname', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'nickname',
      label: 'Nickname', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'email',
      label: 'Email', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'sponsor',
      label: 'Sponsor', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'anniversary',
      label: 'Anniversary', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'birthday',
      label: 'Birthday', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'address',
      label: 'Address', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'apartment_number',
      label: 'Apartment Number', // i18n defer
      searchable: true,
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'building_number',
      label: 'Building Number', // i18n defer
      searchable: true,
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'room_number',
      label: 'Room Number', // i18n defer
      searchable: true,
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'company',
      label: 'Company', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'gender',
      label: 'Gender', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'lang',
      label: 'Language', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'notes',
      label: 'Notes', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'portal',
      label: 'Portal', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'psk',
      label: 'PSK', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'source',
      label: 'Source', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'cell_phone',
      label: 'Cellular Phone Number', // i18n defer
      searchable: true,
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'telephone',
      label: 'Home Telephone Number', // i18n defer
      searchable: true,
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'work_phone',
      label: 'Work Telephone Number', // i18n defer
      searchable: true,
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'custom_field_1',
      label: 'Custom Field #1', // i18n defer
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'custom_field_2',
      label: 'Custom Field #2', // i18n defer
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'custom_field_3',
      label: 'Custom Field #3', // i18n defer
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'custom_field_4',
      label: 'Custom Field #4', // i18n defer
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'custom_field_5',
      label: 'Custom Field #5', // i18n defer
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'custom_field_6',
      label: 'Custom Field #6', // i18n defer
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'custom_field_7',
      label: 'Custom Field #7', // i18n defer
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'custom_field_8',
      label: 'Custom Field #8', // i18n defer
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'custom_field_9',
      label: 'Custom Field #9', // i18n defer
      sortable: true,
      class: 'text-nowrap'
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    }
  ],
  fields: [
    {
      value: 'tenant_id',
      text: 'Tenant', // i18n defer
      types: [conditionType.TENANT]
    },
    {
      value: 'pid',
      text: 'PID', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'title',
      text: 'Title', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'firstname',
      text: 'Firstname', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'lastname',
      text: 'Lastname', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'nickname',
      text: 'Nickname', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'email',
      text: 'Email', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'sponsor',
      text: 'Sponsor', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'anniversary',
      text: 'Anniversary', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'birthday',
      text: 'Birthday', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'address',
      text: 'Address', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'apartment_number',
      text: 'Apartment Number', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'building_number',
      text: 'Building Number', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'room_number',
      text: 'Room Number', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'company',
      text: 'Company', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'gender',
      text: 'Gender', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'lang',
      text: 'Language', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'notes',
      text: 'Notes', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'portal',
      text: 'Portal', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'psk',
      text: 'PSK', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'source',
      text: 'Source', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'cell_phone',
      text: 'Cellular Phone Number', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'telephone',
      text: 'Home Telephone Number', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'work_phone',
      text: 'Work Telephone Number', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'custom_field_1',
      text: 'Custom Field #1', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'custom_field_2',
      text: 'Custom Field #2', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'custom_field_3',
      text: 'Custom Field #3', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'custom_field_4',
      text: 'Custom Field #4', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'custom_field_5',
      text: 'Custom Field #5', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'custom_field_6',
      text: 'Custom Field #6', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'custom_field_7',
      text: 'Custom Field #7', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'custom_field_8',
      text: 'Custom Field #8', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'custom_field_9',
      text: 'Custom Field #9', // i18n defer
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'pid',
  sortDesc: false,
  defaultCondition: () => ({
    op: 'and', values: [
    { op: 'or', values: [
      { field: 'pid', op: 'not_equals', value: null }
    ] }
  ] })
})
