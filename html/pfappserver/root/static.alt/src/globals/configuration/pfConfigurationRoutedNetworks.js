import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import {
  and,
  not,
  conditional,
  hasRoutedNetworks,
  routedNetworkExists,
  isFQDN
} from '@/globals/pfValidators'

const {
  ipAddress,
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationRoutedNetworkTypes = [
  { value: 'dns-enforcement', text: i18n.t('DNS Enforcement') },
  { value: 'inlinel3', text: i18n.t('Inline Layer 3') },
  { value: 'vlan-isolation', text: i18n.t('Isolation') },
  { value: 'vlan-registration', text: i18n.t('Registration') }
]

export const pfConfigurationRoutedNetworkHtmlNote = `<div class="alert alert-warning">
  <strong>${i18n.t('Note')}</strong>
  ${i18n.t('Adding or modifying a network requires a restart of the pfdhcp and pfdns services for the changes to take place.')}
</div>`

export const pfConfigurationRoutedNetworksTypeFormatter = (value, key, item) => {
  if (value === null || value === '') return null
  return pfConfigurationRoutedNetworkTypes.find(type => type.value === value).text
}

export const pfConfigurationRoutedNetworksListColumns = [
  {
    key: 'id',
    label: i18n.t('Network'),
    sortable: false,
    visible: true
  },
  {
    key: 'type',
    label: i18n.t('Type'),
    sortable: false,
    visible: true,
    formatter: pfConfigurationRoutedNetworksTypeFormatter
  },
  {
    key: 'next_hop',
    label: i18n.t('Next Hop'),
    sortable: true,
    visible: true
  },
  {
    key: 'gateway',
    label: i18n.t('Gateway'),
    sortable: true,
    visible: true
  },
  {
    key: 'dns',
    label: i18n.t('DNS'),
    sortable: true,
    visible: true
  },
  {
    key: 'dhcpd',
    label: i18n.t('DHCP'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    sortable: false,
    visible: false,
    locked: true
  }
]

export const pfConfigurationRoutedNetworkViewFields = (context = {}) => {
  const {
    isNew = false,
    isClone = false,
    options: {
      meta = {}
    },
    form = {}
  } = context

  return [
    {
      tab: i18n.t('General'),
      fields: [
        {
          label: i18n.t('Routed Network'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'id', 'Identifier'),
                ...{
                  [i18n.t('Network exists.')]: not(and(required, conditional(isNew || isClone), hasRoutedNetworks, routedNetworkExists)),
                  [i18n.t('Invalid IP Address.')]: ipAddress
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Netmask'),
          fields: [
            {
              key: 'netmask',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'netmask'),
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'netmask', 'Netmask'),
                ...{
                  [i18n.t('Invalid IP Address.')]: ipAddress
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Type'),
          fields: [
            {
              key: 'type',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to add a type'),
                trackBy: 'value',
                label: 'text',
                options: pfConfigurationRoutedNetworkTypes
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'tpye', 'Type')
            }
          ]
        },
        {
          if: form.type === 'inlinel3',
          label: i18n.t('Enable NAT'),
          fields: [
            {
              key: 'nat_enabled',
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
          fields: [
            {
              key: 'fake_mac_enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 1, unchecked: 0 }
              }
            }
          ]
        },
        {
          label: null, /* no label */
          fields: [
            {
              component: pfFormHtml,
              attrs: {
                html: pfConfigurationRoutedNetworkHtmlNote
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('DHCP'),
      fields: [
        {
          label: i18n.t('DHCP Server'),
          fields: [
            {
              key: 'dhcpd',
              component: pfFormRangeToggle,
              attrs: {
                disabled: (form.fake_mac_enabled === 1),
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Starting IP Address'),
          fields: [
            {
              key: 'dhcp_start',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'dhcp_start'),
                ...{
                  disabled: (form.fake_mac_enabled === 1)
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'dhcp_start', 'IP Address'),
                ...{
                  [i18n.t('Invalid IP Address.')]: ipAddress
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Ending IP Address'),
          fields: [
            {
              key: 'dhcp_end',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'dhcp_start'),
                ...{
                  disabled: (form.fake_mac_enabled === 1)
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'dhcp_start', 'IP Address'),
                ...{
                  [i18n.t('Invalid IP Address.')]: ipAddress
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Default Lease Time'),
          fields: [
            {
              key: 'dhcp_default_lease_time',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'dhcp_default_lease_time'),
                ...{
                  disabled: (form.fake_mac_enabled === 1)
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'dhcp_default_lease_time', 'Time')
            }
          ]
        },
        {
          label: i18n.t('Max Lease Time'),
          fields: [
            {
              key: 'dhcp_max_lease_time',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'dhcp_max_lease_time'),
                ...{
                  disabled: (form.fake_mac_enabled === 1)
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'dhcp_max_lease_time', 'Time')
            }
          ]
        },
        {
          label: i18n.t('IP Addresses reserved'),
          text: i18n.t('Range like 192.168.0.1-192.168.0.20 and or IP like 192.168.0.22,192.168.0.24 will be excluded from the DHCP pool.'),
          fields: [
            {
              key: 'ip_reserved',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'ip_reserved'),
                ...{
                  disabled: (form.fake_mac_enabled === 1),
                  rows: 5
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'ip_reserved', 'Addresses')
            }
          ]
        },
        {
          label: i18n.t('IP Addresses assigned'),
          text: i18n.t('List like 00:11:22:33:44:55:192.168.0.12,11:22:33:44:55:66:192.168.0.13.'),
          fields: [
            {
              key: 'ip_assigned',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'ip_assigned'),
                ...{
                  disabled: (form.fake_mac_enabled === 1),
                  rows: 5
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'ip_assigned', 'Addresses')
            }
          ]
        },
        {
          label: i18n.t('DNS Server'),
          text: i18n.t('Should match the IP of a registration interface or the production DNS server(s) if the network is Inline L2/L3 (space delimited list of IP addresses).'),
          fields: [
            {
              key: 'dns',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'dns'),
                ...{
                  disabled: (form.fake_mac_enabled === 1)
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'dns', 'DNS')
            }
          ]
        },
        {
          label: i18n.t('Portal FQDN'),
          text: i18n.t('Define the FQDN of the portal for this network. Leaving empty will use the FQDN of the PacketFence server.'),
          fields: [
            {
              key: 'portal_fqdn',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'portal_fqdn'),
                ...{
                  disabled: (form.fake_mac_enabled === 1)
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'portal_fqdn', 'FQDN'),
                ...{
                  [i18n.t('Invalid FQDN.')]: isFQDN
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Client Gateway'),
          fields: [
            {
              key: 'gateway',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'gateway'),
                ...{
                  disabled: (form.fake_mac_enabled === 1)
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'gateway', 'Gateway'),
                ...{
                  [i18n.t('Invalid IP Address.')]: ipAddress
                }
              }
            }
          ]
        },
        {
          label: null, /* no label */
          fields: [
            {
              component: pfFormHtml,
              attrs: {
                html: pfConfigurationRoutedNetworkHtmlNote
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Routing'),
      fields: [
        {
          label: i18n.t('Router IP'),
          text: i18n.t('IP address of the router to reach this network.'),
          fields: [
            {
              key: 'next_hop',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'next_hop'),
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'next_hop', 'IP Address'),
                ...{
                  [i18n.t('Invalid IP Address.')]: ipAddress
                }
              }
            }
          ]
        },
        {
          label: null, /* no label */
          fields: [
            {
              component: pfFormHtml,
              attrs: {
                html: pfConfigurationRoutedNetworkHtmlNote
              }
            }
          ]
        }
      ]
    }
  ]
}
