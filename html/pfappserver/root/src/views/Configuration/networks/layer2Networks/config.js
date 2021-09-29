import i18n from '@/utils/locale'
import { pfFieldType as fieldType } from '@/globals/pfField'

// default options available to searchable chosen when query is empty
export const commonDevices = {
  1:      'Windows OS',
  2:      'Mac OS X or macOS',
  5:      'Linux OS',
  33450:  'iOS',
  33453:  'Android OS',
  33471:  'BlackBerry OS',
  33507:  'Windows Phone OS',
}

export const deviceAttributes = {
  dhcp_fingerprint: {
    value: 'dhcp_fingerprint',
    text: i18n.t('DHCP fingerprint'),
    types: [fieldType.INTEGER],
    defaultWeight: 10
  },
  dhcp_vendor: {
    value: 'dhcp_vendor',
    text: i18n.t('DHCP vendor'),
    types: [fieldType.INTEGER],
    defaultWeight: 10
  },
  hostname: {
    value: 'hostname',
    text: i18n.t('Hostname'),
    types: [fieldType.INTEGER],
    defaultWeight: 3
  },
  oui: {
    value: 'oui',
    text: i18n.t('OUI (MAC Vendor)'),
    types: [fieldType.INTEGER],
    defaultWeight: 3
  },
  destination_hosts: {
    value: 'destination_hosts',
    text: i18n.t('Destination hosts'),
    types: [fieldType.INTEGER],
    defaultWeight: 5
  },
  mdns_services: {
    value: 'mdns_services',
    text: i18n.t('mDNS services'),
    types: [fieldType.INTEGER],
    defaultWeight: 5
  },
  tcp_syn_signatures: {
    value: 'tcp_syn_signatures',
    text: i18n.t('TCP SYN signatures'),
    types: [fieldType.INTEGER],
    defaultWeight: 10
  },
  tcp_syn_ack_signatures: {
    value: 'tcp_syn_ack_signatures',
    text: i18n.t('TCP SYN ACK signatures'),
    types: [fieldType.INTEGER],
    defaultWeight: 10
  },
  upnp_server_strings: {
    value: 'upnp_server_strings',
    text: i18n.t('UPnP server strings'),
    types: [fieldType.INTEGER],
    defaultWeight: 5
  },
  upnp_user_agents: {
    value: 'upnp_user_agents',
    text: i18n.t('UPnP user-agent'),
    types: [fieldType.INTEGER],
    defaultWeight: 5
  },
  user_agents: {
    value: 'user_agents',
    text: i18n.t('HTTP user-agent'),
    types: [fieldType.INTEGER],
    defaultWeight: 5
  }
}

export const columns = [
  {
    key: 'id',
    label: 'Network', // i18n defer
    sortable: true,
    visible: true,
    required: true
  },
  {
    key: 'description',
    label: 'Description', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'algorithm',
    label: 'Algorithm', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'pool_backend',
    label: 'Backend', // i18n defer
    sortable: true,
    visible: true,
  },
  {
    key: 'dhcp_start',
    label: 'Starting IP Address', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'dhcp_end',
    label: 'Ending IP Address', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'dhcp_default_lease_time',
    label: 'Default Lease Time', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'dhcp_max_lease_time',
    label: 'Max Lease Time', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'portal_fqdn',
    label: 'Portal FQDN', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'netflow_accounting_enabled',
    label: 'Netflow Accounting Enabled', // i18n defer
    sortable: true,
    visible: true
  }
]
