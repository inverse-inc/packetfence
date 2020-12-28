import i18n from '@/utils/locale'

export const routedNetworkList = [
  { value: 'dns-enforcement', text: i18n.t('DNS Enforcement') },
  { value: 'inlinel3', text: i18n.t('Inline Layer 3') },
  { value: 'vlan-isolation', text: i18n.t('Isolation') },
  { value: 'vlan-registration', text: i18n.t('Registration') },
  { value: 'other', text: i18n.t('Other Networks') }
]

export const routedNetworkListFormatter = (value) => {
  if (value === null || value === '') return null
  return routedNetworkList.find(type => type.value === value).text
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
    key: 'type',
    label: 'Type', // i18n defer
    sortable: true,
    visible: true,
    formatter: routedNetworkListFormatter
  },
  {
    key: 'next_hop',
    label: 'Next Hop', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'gateway',
    label: 'Gateway', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'dns',
    label: 'DNS', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'dhcpd',
    label: 'DHCP', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'pool_backend',
    label: 'Backend', // i18n defer
    sortable: false,
    visible: true,
  },
  {
    key: 'netflow_accounting_enabled',
    label: 'Netflow Accounting Enabled', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]
