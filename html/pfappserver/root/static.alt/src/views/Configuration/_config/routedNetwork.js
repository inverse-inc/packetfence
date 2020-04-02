/* eslint-disable camelcase */
import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import {
  and,
  not,
  conditional,
  hasRoutedNetworks,
  routedNetworkExists,
  isFQDN
} from '@/globals/pfValidators'
import {
  required,
  ipAddress
} from 'vuelidate/lib/validators'

export const routedNetworkList = [
  { value: 'dns-enforcement', text: i18n.t('DNS Enforcement') },
  { value: 'inlinel3', text: i18n.t('Inline Layer 3') },
  { value: 'vlan-isolation', text: i18n.t('Isolation') },
  { value: 'vlan-registration', text: i18n.t('Registration') }
]

export const routedNetworkListFormatter = (value) => {
  if (value === null || value === '') return null
  return routedNetworkList.find(type => type.value === value).text
}

export const htmlNote = `<div class="alert alert-warning">
  <strong>${i18n.t('Note')}</strong>
  ${i18n.t('Adding or modifying a network requires a restart of the pfdhcp and pfdns services for the changes to take place.')}
</div>`

export const columns = [
  {
    key: 'id',
    label: 'Network', // i18n defer
    required: true,
    visible: true
  },
  {
    key: 'type',
    label: 'Type', // i18n defer
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
    key: 'buttons',
    label: '',
    locked: true
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
  }
]

export const view = (form = {}, meta = {}) => {
  const {
    fake_mac_enabled
  } = form
  const {
    isNew = false,
    isClone = false
  } = meta
  return [
    {
      tab: i18n.t('General'),
      rows: [
        {
          label: 'Routed Network', // i18n defer
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              }
            }
          ]
        },
        {
          label: 'Netmask', // i18n defer
          cols: [
            {
              namespace: 'netmask',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'netmask')
            }
          ]
        },
        {
          label: 'Type', // i18n defer
          cols: [
            {
              namespace: 'type',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to add a type'),
                trackBy: 'value',
                label: 'text',
                options: routedNetworkList
              }
            }
          ]
        },
        {
          if: form.type === 'inlinel3',
          label: 'Enable NAT', // i18n defer
          cols: [
            {
              namespace: 'nat_enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 1, unchecked: 0 }
              }
            }
          ]
        },
        {
          if: form.type === 'inlinel3',
          label: 'Fake MAC Address', // i18n defer
          cols: [
            {
              namespace: 'fake_mac_enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 1, unchecked: 0 }
              }
            }
          ]
        },
        {
          if: form.type === 'inlinel3',
          label: 'Enable CoA', // i18n defer
          text: i18n.t('Enabling this will send a CoA request to the equipment to reevaluate network access of endpoints.'),
          cols: [
            {
              namespace: 'coa',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: form.type === 'inlinel3',
          label: 'Netflow Accounting Enabled', // i18n defer
          text: i18n.t('Enable Netflow on this network to enable accounting.'),
          cols: [
            {
              namespace: 'netflow_accounting_enabled',
              component: pfFormRangeToggle,
              attrs: {
                ...attributesFromMeta(meta, 'netflow_accounting_enabled'),
                ...{
                  values: { checked: 'enabled', unchecked: 'disabled' }
                }
              }
            }
          ]
        },
        {
          label: null, /* no label */
          cols: [
            {
              component: pfFormHtml,
              attrs: {
                html: htmlNote
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('DHCP'),
      rows: [
        {
          label: 'DHCP Server', // i18n defer
          cols: [
            {
              namespace: 'dhcpd',
              component: pfFormRangeToggle,
              attrs: {
                disabled: (fake_mac_enabled === '1'),
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Algorithm', // i18n defer
          cols: [
            {
              namespace: 'algorithm',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'algorithm'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: 'DHCP Pool Backend Type', // i18n defer
          cols: [
            {
              namespace: 'pool_backend',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'pool_backend'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: 'Starting IP Address', // i18n defer
          cols: [
            {
              namespace: 'dhcp_start',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'dhcp_start'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: 'Ending IP Address', // i18n defer
          cols: [
            {
              namespace: 'dhcp_end',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'dhcp_start'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: 'Default Lease Time', // i18n defer
          cols: [
            {
              namespace: 'dhcp_default_lease_time',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'dhcp_default_lease_time'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: 'Max Lease Time', // i18n defer
          cols: [
            {
              namespace: 'dhcp_max_lease_time',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'dhcp_max_lease_time'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: 'IP Addresses reserved', // i18n defer
          text: i18n.t('Range like 192.168.0.1-192.168.0.20 and or IP like 192.168.0.22,192.168.0.24 will be excluded from the DHCP pool.'),
          cols: [
            {
              namespace: 'ip_reserved',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'ip_reserved'),
                ...{
                  disabled: (fake_mac_enabled === '1'),
                  rows: 5
                }
              }
            }
          ]
        },
        {
          label: 'IP Addresses assigned', // i18n defer
          text: i18n.t('List like 00:11:22:33:44:55:192.168.0.12,11:22:33:44:55:66:192.168.0.13.'),
          cols: [
            {
              namespace: 'ip_assigned',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'ip_assigned'),
                ...{
                  disabled: (fake_mac_enabled === '1'),
                  rows: 5
                }
              }
            }
          ]
        },
        {
          label: 'DNS Server', // i18n defer
          text: i18n.t('Should match the IP of a registration interface or the production DNS server(s) if the network is Inline L2/L3 (space delimited list of IP addresses).'),
          cols: [
            {
              namespace: 'dns',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'dns'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: 'Portal FQDN', // i18n defer
          text: i18n.t('Define the FQDN of the portal for this network. Leaving empty will use the FQDN of the PacketFence server.'),
          cols: [
            {
              namespace: 'portal_fqdn',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'portal_fqdn'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: 'Client Gateway', // i18n defer
          cols: [
            {
              namespace: 'gateway',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'gateway'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: null, /* no label */
          cols: [
            {
              component: pfFormHtml,
              attrs: {
                html: htmlNote
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Routing'),
      rows: [
        {
          label: 'Router IP', // i18n defer
          text: i18n.t('IP address of the router to reach this network.'),
          cols: [
            {
              namespace: 'next_hop',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'next_hop')
            }
          ]
        },
        {
          label: null, /* no label */
          cols: [
            {
              component: pfFormHtml,
              attrs: {
                html: htmlNote
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', 'ID'),
      ...{
        [i18n.t('Network exists.')]: not(and(required, conditional(isNew || isClone), hasRoutedNetworks, routedNetworkExists)),
        [i18n.t('Invalid IP Address.')]: ipAddress
      }
    },
    netmask: {
      ...validatorsFromMeta(meta, 'netmask', i18n.t('Netmask')),
      ...{
        [i18n.t('Invalid IP Address.')]: ipAddress
      }
    },
    type: validatorsFromMeta(meta, 'type', i18n.t('Type')),
    algorithm: validatorsFromMeta(meta, 'algorithm', i18n.t('Algorithm')),
    pool_backend: validatorsFromMeta(meta, 'pool_backend', i18n.t('DHCP Pool Backend Type')),
    dhcp_start: {
      ...validatorsFromMeta(meta, 'dhcp_start', 'IP'),
      ...{
        [i18n.t('Invalid IP Address.')]: ipAddress
      }
    },
    dhcp_end: {
      ...validatorsFromMeta(meta, 'dhcp_end', 'IP'),
      ...{
        [i18n.t('Invalid IP Address.')]: ipAddress
      }
    },
    dhcp_default_lease_time: validatorsFromMeta(meta, 'dhcp_default_lease_time', i18n.t('Time')),
    dhcp_max_lease_time: validatorsFromMeta(meta, 'dhcp_max_lease_time', i18n.t('Time')),
    ip_reserved: validatorsFromMeta(meta, 'ip_reserved', i18n.t('Addresses')),
    ip_assigned: validatorsFromMeta(meta, 'ip_assigned', i18n.t('Addresses')),
    dns: validatorsFromMeta(meta, 'dns', 'DNS'),
    portal_fqdn: {
      ...validatorsFromMeta(meta, 'portal_fqdn', 'FQDN'),
      ...{
        [i18n.t('Invalid FQDN.')]: isFQDN
      }
    },
    gateway: {
      ...validatorsFromMeta(meta, 'gateway', i18n.t('Gateway')),
      ...{
        [i18n.t('Invalid IP Address.')]: ipAddress
      }
    },
    next_hop: {
      ...validatorsFromMeta(meta, 'next_hop', 'IP'),
      ...{
        [i18n.t('Invalid IP Address.')]: ipAddress
      }
    }
  }
}
