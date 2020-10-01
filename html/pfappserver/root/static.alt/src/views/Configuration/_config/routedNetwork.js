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
  or,
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

export const view = (form = {}, meta = {}) => {
  const {
    fake_mac_enabled,
    dhcpd
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
          label: i18n.t('Routed Network'),
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
          label: i18n.t('Netmask'),
          cols: [
            {
              namespace: 'netmask',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'netmask')
            }
          ]
        },
        {
          label: i18n.t('Type'),
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
          label: i18n.t('Enable NAT'),
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
          label: i18n.t('Fake MAC Address'),
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
          label: i18n.t('Enable CoA'),
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
          label: i18n.t('Netflow Accounting Enabled'),
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
          label: i18n.t('DHCP Server'),
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
          if: (dhcpd === 'enabled'),
          label: i18n.t('Algorithm'),
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
          if: (dhcpd === 'enabled'),
          label: i18n.t('DHCP Pool Backend Type'),
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
          label: i18n.t('Starting IP Address'),
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
          label: i18n.t('Ending IP Address'),
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
          label: i18n.t('Default Lease Time'),
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
          label: i18n.t('Max Lease Time'),
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
          label: i18n.t('IP Addresses reserved'),
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
          label: i18n.t('IP Addresses assigned'),
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
          label: i18n.t('DNS Server'),
          text: i18n.t('Should match the IP of a registration interface or the production DNS server(s) if the network is Inline L2/L3 (comma delimited list of IP addresses).'),
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
          label: i18n.t('Portal FQDN'),
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
          label: i18n.t('Client Gateway'),
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
          label: i18n.t('Router IP'),
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
    dhcpd
  } = form
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
    algorithm: {
      ...((dhcpd === 'enabled')
        ? validatorsFromMeta(meta, 'algorithm', i18n.t('Algorithm'))
        : {}
      )
    },
    pool_backend: {
      ...((dhcpd === 'enabled')
        ? {
          ...validatorsFromMeta(meta, 'pool_backend', i18n.t('DHCP pool backend type')),
          [i18n.t('Pool backend type required.')]: required
        }
        : {}
      )
    },
    dhcp_start: {
      ...validatorsFromMeta(meta, 'dhcp_start', 'IP'),
      ...{
        [i18n.t('Invalid IP Address.')]: ipAddress
      },
      ...((dhcpd === 'enabled')
        ? {
          [i18n.t('Starting IP address required.')]: required
        }
        : {}
      )
    },
    dhcp_end: {
      ...validatorsFromMeta(meta, 'dhcp_end', 'IP'),
      ...{
        [i18n.t('Invalid IP Address.')]: ipAddress
      },
      ...((dhcpd === 'enabled')
        ? {
          [i18n.t('Ending IP address required.')]: required
        }
        : {}
      )
    },
    dhcp_default_lease_time: {
      ...validatorsFromMeta(meta, 'dhcp_default_lease_time', i18n.t('Time')),
      ...((dhcpd === 'enabled')
        ? {
          [i18n.t('Default lease time required.')]: required
        }
        : {}
      )
    },
    dhcp_max_lease_time: {
      ...validatorsFromMeta(meta, 'dhcp_max_lease_time', i18n.t('Time')),
      ...((dhcpd === 'enabled')
        ? {
          [i18n.t('Max lease time required.')]: required
        }
        : {}
      )
    },
    ip_reserved: validatorsFromMeta(meta, 'ip_reserved', i18n.t('Addresses')),
    ip_assigned: validatorsFromMeta(meta, 'ip_assigned', i18n.t('Addresses')),
    dns: {
      ...validatorsFromMeta(meta, 'dns', 'DNS'),
      ...((dhcpd === 'enabled')
        ? {
          [i18n.t('DNS server required.')]: required
        }
        : {}
      )
    },
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
      },
      ...((dhcpd === 'enabled')
        ? {
          [i18n.t('Gateway required.')]: required
        }
        : {}
      )
    },
    next_hop: {
      ...validatorsFromMeta(meta, 'next_hop', 'IP'),
      ...{
        [i18n.t('Invalid IP Address.')]: ipAddress
      }
    }
  }
}
