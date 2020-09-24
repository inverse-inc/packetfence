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
    visible: true,
    required: false
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
