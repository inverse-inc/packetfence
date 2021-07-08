import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from './_api'

export const useSearch = makeSearch('statusNetwork', {
  api,
  columns: Object.entries({
    mac:                  'MAC Address',
    computername:         'Computer Name',
    device_class:         'Device Class',
    device_manufacturer:  'Device Manufacturer',
    device_type:          'Debice Type',
    device_version:       'Device Version',
    'ip4log.ip':          'IPv4 Address',
    'locationlog.ssid':   'SSID',
    machine_account:      'Machine Account',
    pid:                  'Owner',
    user_agent:           'User Agent'
  }).map(([key, label]) => ({
    key, label, searchable: true
  })),
  fields: [
    {
      value: 'tenant_id',
      text: 'Tenant', // i18n defer
      types: [conditionType.INTEGER]
    },
    {
      value: 'status',
      text: 'Status', // i18n defer
      types: [conditionType.NODE_STATUS],
      icon: 'power-off'
    },
    {
      value: 'mac',
      text: 'MAC Address', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'id-card'
    },
    {
      value: 'bypass_role_id',
      text: 'Bypass Role', // i18n defer
      types: [conditionType.ROLE, conditionType.SUBSTRING],
      icon: 'project-diagram'
    },
    {
      value: 'bypass_vlan',
      text: 'Bypass VLAN', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'project-diagram'
    },
    {
      value: 'computername',
      text: 'Computer Name', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'desktop'
    },
    {
      value: 'locationlog.connection_type',
      text: 'Connection Type', // i18n defer
      types: [conditionType.CONNECTION_TYPE],
      icon: 'plug'
    },
    {
      value: 'detect_date',
      text: 'Detected Date', // i18n defer
      types: [conditionType.DATETIME],
      icon: 'calendar-alt'
    },
    {
      value: 'regdate',
      text: 'Registered Date', // i18n defer
      types: [conditionType.DATETIME],
      icon: 'calendar-alt'
    },
    {
      value: 'unregdate',
      text: 'Unregistered Date', // i18n defer
      types: [conditionType.DATETIME],
      icon: 'calendar-alt'
    },
    {
      value: 'last_arp',
      text: 'Last ARP Date', // i18n defer
      types: [conditionType.DATETIME],
      icon: 'calendar-alt'
    },
    {
      value: 'last_dhcp',
      text: 'Last DHCP Date', // i18n defer
      types: [conditionType.DATETIME],
      icon: 'calendar-alt'
    },
    {
      value: 'last_seen',
      text: 'Last seen Date', // i18n defer
      types: [conditionType.DATETIME],
      icon: 'calendar-alt'
    },
    {
      value: 'device_class',
      text: 'Device Class', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'barcode'
    },
    {
      value: 'device_manufacturer',
      text: 'Device Manufacturer', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'barcode'
    },
    {
      value: 'device_type',
      text: 'Device Type', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'barcode'
    },
    {
      value: 'device_version',
      text: 'Device Version', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'barcode'
    },
    {
      value: 'ip4log.ip',
      text: 'IPv4 Address', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'project-diagram'
    },
    /*
    {
      value: 'ip6log.ip',
      text: 'IPv6 Address', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'project-diagram'
    },
    */
    {
      value: 'machine_account',
      text: 'Machine Account', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'desktop'
    },
    {
      value: 'notes',
      text: 'Notes', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'notes-medical'
    },
    {
      value: 'online',
      text: 'Online Status', // i18n defer
      types: [conditionType.ONLINE],
      icon: 'power-off'
    },
    {
      value: 'pid',
      text: 'Owner', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'user'
    },
    {
      value: 'category_id',
      text: 'Role', // i18n defer
      types: [conditionType.ROLE, conditionType.SUBSTRING],
      icon: 'project-diagram'
    },
    {
      value: 'locationlog.switch',
      text: 'Source Switch Identifier', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'sitemap'
    },
    {
      value: 'locationlog.switch_ip',
      text: 'Source Switch IP', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'sitemap'
    },
    {
      value: 'locationlog.switch_mac',
      text: 'Source Switch MAC', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'sitemap'
    },
    {
      value: 'locationlog.port',
      text: 'Source Switch Port', // i18n defer
      types: [conditionType.INTEGER],
      icon: 'sitemap'
    },
    {
      value: 'locationlog.ifDesc',
      text: 'Source Switch Port Description', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'sitemap'
    },
    {
      value: 'locationlog.ifDesc',
      text: 'Source Switch Description', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'sitemap'
    },
    {
      value: 'locationlog.ssid',
      text: 'SSID', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'wifi'
    },
    {
      value: 'user_agent',
      text: 'User Agent', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'user-secret'
    },
    /* TODO - #3400, #4166
    {
      value: 'security_event.open_security_event_id',
      text: 'Security Event Open', // i18n defer
      types: [conditionType.SECURITY_EVENT],
      icon: 'exclamation-triangle'
    },
    {
      value: 'security_event.open_count',
      text: 'Security Event Open Count [Issue #3400]', // i18n defer
      types: [conditionType.INTEGER],
      icon: 'exclamation-triangle'
    },
    {
      value: 'security_event.close_security_event_id',
      text: 'Security Event Closed', // i18n defer
      types: [conditionType.SECURITY_EVENT],
      icon: 'exclamation-circle'
    },
    {
      value: 'security_event.close_count',
      text: 'Security Event Close Count [Issue #3400]', // i18n defer
      types: [conditionType.INTEGER],
      icon: 'exclamation-circle'
    },
    */
    {
      value: 'voip',
      text: 'VoIP', // i18n defer
      types: [conditionType.YESNO],
      icon: 'phone'
    },
    {
      value: 'autoreg',
      text: 'Auto Registration', // i18n defer
      types: [conditionType.YESNO],
      icon: 'magic'
    },
    {
      value: 'bandwidth_balance',
      text: 'Bandwidth Balance', // i18n defer
      types: [conditionType.PREFIXMULTIPLE],
      icon: 'balance-scale'
    }
  ],
  sortBy: 'last_seen',
  sortDesc: true,
  defaultCondition: () => ({
    op: 'and', values: [
    { op: 'or', values: [
      { field: 'last_seen', op: 'greater_than', value: '' }
    ] }
  ] })
})
