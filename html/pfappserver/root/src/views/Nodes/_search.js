import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import makeSearch from '@/store/factory/search'
import acl from '@/utils/acl'
import bytes from '@/utils/bytes'
import api from './_api'

export const useSearch = makeSearch('nodes', {
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
      key: 'status',
      label: 'Status', // i18n defer
      sortable: true,
      visible: true
    },
    {
      key: 'online',
      label: 'Online', // i18n defer
      sortable: true,
      visible: true
    },
    {
      key: 'mac',
      label: 'MAC Address', // i18n defer
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'detect_date',
      label: 'Detected Date', // i18n defer
      searchable: true,
      sortable: true,
      formatter: formatter.datetimeIgnoreZero,
      class: 'text-nowrap'
    },
    {
      key: 'regdate',
      label: 'Registration Date', // i18n defer
      sortable: true,
      formatter: formatter.datetimeIgnoreZero,
      class: 'text-nowrap'
    },
    {
      key: 'unregdate',
      label: 'Unregistration Date', // i18n defer
      searchable: true,
      sortable: true,
      formatter: formatter.datetimeIgnoreZero,
      class: 'text-nowrap'
    },
    {
      key: 'computername',
      label: 'Computer Name', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'pid',
      label: 'Owner', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'ip4log.ip',
      label: 'IPv4 Address', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'ip6log.ip',
      label: 'IPv6 Address', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'device_class',
      label: 'Device Class', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'device_manufacturer',
      label: 'Device Manufacturer', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'device_score',
      label: 'Device Score', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'device_type',
      label: 'Device Type', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'device_version',
      label: 'Device Version', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'dhcp6_enterprise',
      label: 'DHCPv6 Enterprise', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'dhcp6_fingerprint',
      label: 'DHCPv6 Fingerprint', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'dhcp_fingerprint',
      label: 'DHCP Fingerprint', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'category_id',
      label: 'Role', // i18n defer
      searchable: true,
      sortable: true,
      visible: true,
      formatter: formatter.categoryId
    },
    {
      key: 'locationlog.connection_type',
      label: 'Connection Type', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'locationlog.session_id',
      label: 'Session ID', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'locationlog.switch',
      label: 'Switch Identifier', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'locationlog.switch_ip',
      label: 'Switch IP Address', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'locationlog.switch_mac',
      label: 'Switch MAC Address', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'locationlog.port',
      label: 'Switch Port', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'locationlog.ifDesc',
      label: 'Switch Port Description', // i18n defer
      sortable: true
    },
    {
      key: 'locationlog.ssid',
      label: 'SSID', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'locationlog.vlan',
      label: 'VLAN', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'bypass_vlan',
      label: 'Bypass VLAN', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'bypass_role_id',
      label: 'Bypass Role', // i18n defer
      searchable: true,
      sortable: true,
      formatter: formatter.bypassRoleId
    },
    {
      key: 'notes',
      label: 'Notes', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'voip',
      label: 'VoIP', // i18n defer
      sortable: true
    },
    {
      key: 'last_arp',
      label: 'Last ARP', // i18n defer
      sortable: true,
      formatter: formatter.datetimeIgnoreZero,
      class: 'text-nowrap'
    },
    {
      key: 'last_dhcp',
      label: 'Last DHCP', // i18n defer
      sortable: true,
      formatter: formatter.datetimeIgnoreZero,
      class: 'text-nowrap'
    },
    {
      key: 'last_seen',
      label: 'Last seen', // i18n defer
      sortable: true,
      formatter: formatter.datetimeIgnoreZero,
      class: 'text-nowrap'
    },
    {
      key: 'machine_account',
      label: 'Machine Account', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'autoreg',
      label: 'Auto Registration', // i18n defer
      sortable: true
    },
    {
      key: 'bandwidth_balance',
      label: 'Bandwidth Balance', // i18n defer
      sortable: true,
      formatter: value => ((value)
        ? `${bytes.toHuman(value, 2, true)}B`
        : ''
      )
    },
    {
      key: 'time_balance',
      label: 'Time Balance', // i18n defer
      sortable: true
    },
    {
      key: 'user_agent',
      label: 'User Agent', // i18n defer
      searchable: true,
      sortable: true
    },
    {
      key: 'security_event.open_security_event_id',
      label: 'Security Event Open', // i18n defer
      sortable: true,
      class: 'text-nowrap',
      formatter: (acl.$can.apply(null, ['read', 'security_events']))
        ? formatter.securityEventIdsToDescCsv
        : formatter.noAdminRolePermission
    },
    /* TODO - #4166
    {
      key: 'security_event.open_count',
      label: 'Security Event Open Count', // i18n defer
      sortable: true,
      class: 'text-nowrap'
    },
    */
    {
      key: 'security_event.close_security_event_id',
      label: 'Security Event Closed', // i18n defer
      sortable: true,
      class: 'text-nowrap',
      formatter: (acl.$can.apply(null, ['read', 'security_events']))
        ? formatter.securityEventIdsToDescCsv
        : formatter.noAdminRolePermission
    },
    /* TODO - #4166
    {
      key: 'security_event.close_count',
      label: 'Security Event Closed Count', // i18n defer
      sortable: true,
      class: 'text-nowrap'
    }
    */
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
      types: [conditionType.TENANT],
      icon: 'layer-group'
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
      value: 'ip4log.ip',
      text: 'IPv4 Address', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'project-diagram'
    },
    {
      value: 'ip6log.ip',
      text: 'IPv6 Address', // i18n defer
      types: [conditionType.SUBSTRING],
      icon: 'project-diagram'
    },
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
      types: [conditionType.SWITCH_IP],
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
  sortBy: 'mac',
  sortDesc: true,
  defaultCondition: () => ({
    op: 'and', values: [
    { op: 'or', values: [
      { field: 'mac', op: 'not_equals', value: null }
    ] }
  ] })
})
