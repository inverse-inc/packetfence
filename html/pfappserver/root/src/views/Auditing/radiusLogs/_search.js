import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import makeSearch from '@/store/factory/search'
import api from './_api'

export const useSearch = makeSearch('radiusLogs', {
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
      required: true,
      searchable: true,
      sortable: true
    },
    {
      key: 'created_at',
      label: 'Created At', // i18n defer
      searchable: false,
      sortable: true,
      visible: true,
      formatter: formatter.datetimeIgnoreZero
    },
    {
      key: 'auth_status',
      label: 'Auth Status', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'radius_ip',
      label: 'Server IP', // i18n defer
      searchable: false,
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
      key: 'auth_type',
      label: 'Auth Type', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'auto_reg',
      label: 'Auto Reg', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'calling_station_id',
      label: 'Calling Station ID', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'computer_name',
      label: 'Computer Name', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'eap_type',
      label: 'EAP Type', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'event_type',
      label: 'Event Type', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'ip',
      label: 'IP Address', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'is_phone',
      label: 'Is a Phone', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'node_status',
      label: 'Node Status', // i18n defer
      searchable: false,
      sortable: true,
      visible: true
    },
    {
      key: 'pf_domain',
      label: 'Domain', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'profile',
      label: 'Profile', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'realm',
      label: 'Realm', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'reason',
      label: 'Reason', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'role',
      label: 'Role', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'source',
      label: 'Source', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'stripped_user_name',
      label: 'Stripped User Name', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'user_name',
      label: 'User Name', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'uuid',
      label: 'Unique ID', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'switch_id',
      label: 'Switch', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'switch_mac',
      label: 'Switch MAC', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'switch_ip_address',
      label: 'Switch IP Address', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'called_station_id',
      label: 'Called Station ID', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'connection_type',
      label: 'Connection Type', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'ifindex',
      label: 'IfIndex', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'nas_identifier',
      label: 'NAS ID', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'nas_ip_address',
      label: 'NAS IP Address', // i18n defer
      searchable: false,
      sortable: true,
      visible: true
    },
    {
      key: 'nas_port',
      label: 'NAS Port', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'nas_port_id',
      label: 'NAS Port ID', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'nas_port_type',
      label: 'NAS Port Type', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'radius_source_ip_address',
      label: 'RADIUS Source IP Address', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'ssid',
      label: 'SSID', // i18n defer
      searchable: false,
      sortable: true,
      visible: true
    },
    {
      key: 'request_time',
      label: 'Request Time', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'radius_request',
      label: 'RADIUS Request', // i18n defer
      searchable: false,
      sortable: true
    },
    {
      key: 'radius_reply',
      label: 'RADIUS Reply', // i18n defer
      searchable: false,
      sortable: true
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
      value: 'auth_status',
      text: 'Auth Status', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'auth_type',
      text: 'Auth Type', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'radius_ip',
      text: 'Server IP', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'auto_reg',
      text: 'Auto Registration', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'called_station_id',
      text: 'Called Station ID', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'calling_station_id',
      text: 'Calling Station ID', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'computer_name',
      text: 'Computer Name', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'profile',
      text: 'Connection Profile', // i18n defer
      types: [conditionType.CONNECTION_PROFILE]
    },
    {
      value: 'connection_type',
      text: 'Connection Type', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'created_at',
      text: 'Created', // i18n defer
      types: [conditionType.DATETIME]
    },
    {
      value: 'pf_domain',
      text: 'Domain', // i18n defer
      types: [conditionType.DOMAIN]
    },
    {
      value: 'eap_type',
      text: 'EAP Type', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'event_type',
      text: 'Event Type', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'ifindex',
      text: 'IfIndex', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'ip',
      text: 'IP Address', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'is_phone',
      text: 'Is a Phone', // i18n defer
      types: [conditionType.YESNO]
    },
    {
      value: 'mac',
      text: 'MAC Address', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'nas_identifier',
      text: 'NAS Identifier', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'nas_ip_address',
      text: 'NAS IP Address', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'nas_port',
      text: 'NAS Port', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'nas_port_id',
      text: 'NAS Port ID', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'nas_port_type',
      text: 'NAS Port Type', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'node_status',
      text: 'Node Status', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'pf_domain',
      text: 'Domain', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'profile',
      text: 'Profile', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'radius_reply',
      text: 'RADIUS Reply', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'radius_request',
      text: 'RADIUS Request', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'radius_source_ip_address',
      text: 'RADIUS Source IP Address', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'realm',
      text: 'Realm', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'reason',
      text: 'Reason', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'request_time',
      text: 'Request Time', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'role',
      text: 'Role', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'source',
      text: 'Source', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'ssid',
      text: 'Wi-Fi Network SSID', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'stripped_user_name',
      text: 'Stripped User Name', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'switch_id',
      text: 'Switch ID', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'switch_ip_address',
      text: 'Switch IP Address', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'switch_mac',
      text: 'Switch MAC', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'user_name',
      text: 'User Name', // i18n defer
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'uuid',
      text: 'Unique ID', // i18n defer
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'created_at',
  sortDesc: true
})
