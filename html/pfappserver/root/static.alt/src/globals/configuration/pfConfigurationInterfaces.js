import i18n from '@/utils/locale'
import network from '@/utils/network'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  and,
  not,
  ipv6Address,
  isCIDR,
  isVLAN,
  hasInterfaces,
  interfaceVlanExists
} from '@/globals/pfValidators'

const {
  required,
  ipAddress
} = require('vuelidate/lib/validators')

export const pfConfigurationInterfaceTypes = [
  { value: 'none', text: i18n.t('None') },
  { value: 'dns-enforcement', text: i18n.t('DNS Enforcement') },
  { value: 'inlinel2', text: i18n.t('Inline Layer 2') },
  { value: 'management', text: i18n.t('Management') },
  { value: 'portal', text: i18n.t('Portal') },
  { value: 'vlan-isolation', text: i18n.t('Isolation') },
  { value: 'vlan-registration', text: i18n.t('Registration') },
  { value: 'other', text: i18n.t('Other') }
]

export const pfCongigurationInterfaceDaemons = [
  { value: 'dhcp', text: 'dhcp' },
  { value: 'dns', text: 'dns' },
  { value: 'portal', text: 'portal' },
  { value: 'radius', text: 'radius' }

]

export const pfConfigurationInterfacesTypeFormatter = (value, key, item) => {
  if (value === null || value === '') return null
  return pfConfigurationInterfaceTypes.find(type => type.value === value).text
}

export const pfConfigurationInterfacesSortColumns = { // maintain hierarchical ordering (master => vlans)
  id: (itemA, itemB, sortDesc) => {
    const sortMod = (sortDesc) ? -1 : 1
    switch (true) {
      case (!!itemA.vlan && !itemB.vlan && itemA.master === itemB.id): // B is master of A
        return 1 * sortMod
      case (!itemA.vlan && !!itemB.vlan && itemA.id === itemB.master): // A is master of B
        return -1 * sortMod
      case (itemA.name === itemB.name):
        return parseInt(itemA.vlan) - parseInt(itemB.vlan)
      default:
        return itemA.id.localeCompare(itemB.id)
    }
  },
  ipaddress: (itemA, itemB, sortDesc, context = {}) => {
    const {
      interfaces
    } = context
    const id2ip = {} // map (name => ipaddress) of non-vlan interfaces
    interfaces.forEach(item => {
      if (!item.vlan && item.ipaddress) {
        id2ip[item.name] = item.ipaddress
      }
    })
    const sortMod = (sortDesc) ? -1 : 1
    switch (true) {
      case (!itemA.vlan && !itemB.vlan): // both are master
        return network.ipv4Sort(itemA.ipaddress, itemB.ipaddress)
      case (!!itemA.vlan && !!itemB.vlan): // both are VLAN
        if (itemA.master === itemB.master) { // both vlans, same master
          return network.ipv4Sort(itemA.ipaddress, itemB.ipaddress)
        } else { // both vlans, different master
          return network.ipv4Sort(id2ip[itemA.name], id2ip[itemB.name])
        }
      case (!!itemA.vlan && !itemB.vlan): // only A is VLAN
        if (itemA.master === itemB.id) { // B is master of A
          return 1 * sortMod
        } else {
          return network.ipv4Sort(id2ip[itemA.name], itemB.ipaddress)
        }
      case (!itemA.vlan && !!itemB.vlan): // only B is VLAN
        if (itemA.id === itemB.master) { // A is master of B
          return -1 * sortMod
        } else {
          return network.ipv4Sort(itemA.ipaddress, id2ip[itemB.name])
        }
    }
  },
  netmask: (itemA, itemB, sortDesc, context = {}) => {
    const {
      interfaces
    } = context
    const id2netmask = {} // map (name => netmask) of non-vlan interfaces
    interfaces.forEach(item => {
      if (!item.vlan && item.netmask) {
        id2netmask[item.name] = item.netmask
      }
    })
    const sortMod = (sortDesc) ? -1 : 1
    switch (true) {
      case (!itemA.vlan && !itemB.vlan): // both are master
        return network.ipv4Sort(itemA.netmask, itemB.netmask)
      case (!!itemA.vlan && !!itemB.vlan): // both are VLAN
        if (itemA.master === itemB.master) { // both vlans, same master
          return network.ipv4Sort(itemA.netmask, itemB.netmask)
        } else { // both vlans, different master
          return network.ipv4Sort(id2netmask[itemA.name], id2netmask[itemB.name])
        }
      case (!!itemA.vlan && !itemB.vlan): // only A is VLAN
        if (itemA.master === itemB.id) { // B is master of A
          return 1 * sortMod
        } else {
          return network.ipv4Sort(id2netmask[itemA.name], itemB.netmask)
        }
      case (!itemA.vlan && !!itemB.vlan): // only B is VLAN
        if (itemA.id === itemB.master) { // A is master of B
          return -1 * sortMod
        } else {
          return network.ipv4Sort(itemA.netmask, id2netmask[itemB.name])
        }
    }
  },
  network: (itemA, itemB, sortDesc, context = {}) => {
    const {
      interfaces
    } = context
    const id2network = {} // map (name => network) of non-vlan interfaces
    interfaces.forEach(item => {
      if (!item.vlan && item.network) {
        id2network[item.name] = item.network
      }
    })
    const sortMod = (sortDesc) ? -1 : 1
    switch (true) {
      case (!itemA.vlan && !itemB.vlan): // both are master
        return network.ipv4Sort(itemA.network, itemB.network)
      case (!!itemA.vlan && !!itemB.vlan): // both are VLAN
        if (itemA.master === itemB.master) { // both vlans, same master
          return network.ipv4Sort(itemA.network, itemB.network)
        } else { // both vlans, different master
          return network.ipv4Sort(id2network[itemA.name], id2network[itemB.name])
        }
      case (!!itemA.vlan && !itemB.vlan): // only A is VLAN
        if (itemA.master === itemB.id) { // B is master of A
          return 1 * sortMod
        } else {
          return network.ipv4Sort(id2network[itemA.name], itemB.network)
        }
      case (!itemA.vlan && !!itemB.vlan): // only B is VLAN
        if (itemA.id === itemB.master) { // A is master of B
          return -1 * sortMod
        } else {
          return network.ipv4Sort(itemA.network, id2network[itemB.name])
        }
    }
  }
}

export const pfConfigurationInterfacesListColumns = [
  {
    key: 'is_running',
    label: i18n.t('Status'),
    sortable: false,
    visible: true
  },
  {
    key: 'id',
    label: i18n.t('Logical Name'),
    sortable: true,
    visible: true,
    sort: pfConfigurationInterfacesSortColumns.id
  },
  {
    key: 'ipaddress',
    label: i18n.t('IPv4 Address'),
    sortable: true,
    visible: true,
    sort: pfConfigurationInterfacesSortColumns.ipaddress
  },
  {
    key: 'ipv6_address',
    label: i18n.t('IPv6 Address'),
    sortable: true,
    visible: true
  },
  {
    key: 'ipv6_prefix',
    label: i18n.t('IPv6 Prefix'),
    sortable: true,
    visible: true
  },
  {
    key: 'netmask',
    label: i18n.t('Netmask'),
    sortable: true,
    visible: true,
    sort: pfConfigurationInterfacesSortColumns.netmask
  },
  {
    key: 'network',
    label: i18n.t('Default Network'),
    sortable: true,
    visible: true,
    sort: pfConfigurationInterfacesSortColumns.network
  },
  {
    key: 'type',
    label: i18n.t('Type'),
    sortable: false,
    visible: true,
    formatter: pfConfigurationInterfacesTypeFormatter
  },
  {
    key: 'additional_listening_daemons',
    label: i18n.t('Daemons'),
    sortable: false,
    visible: true
  },
  {
    key: 'high_availability',
    label: i18n.t('High Availability'),
    sortable: false,
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

export const pfConfigurationInterfaceViewFields = (context = {}) => {
  const {
    isNew = false,
    isClone = false,
    isVlan = false,
    id = null,
    form = {}
  } = context

  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('Interface'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: true
              }
            }
          ]
        },
        {
          if: (isNew || isClone || isVlan),
          label: i18n.t('Virtual LAN ID'),
          fields: [
            {
              key: 'vlan',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('VLAN required.')]: required,
                [i18n.t('Invalid VLAN.')]: isVLAN,
                [i18n.t('VLAN exists.')]: not(and(required, hasInterfaces, interfaceVlanExists(id)))
              }
            }
          ]
        },
        {
          label: i18n.t('IPv4 Address'),
          fields: [
            {
              key: 'ipaddress',
              component: pfFormInput,
              validators: {
                [i18n.t('Invalid IPv4 address.')]: ipAddress
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
              validators: {
                [i18n.t('Invalid IPv4 address.')]: ipAddress
              }
            }
          ]
        },
        {
          label: i18n.t('IPv6 Address'),
          fields: [
            {
              key: 'ipv6_address',
              component: pfFormInput,
              validators: {
                [i18n.t('Invalid IPv6 address.')]: ipv6Address
              }
            }
          ]
        },
        {
          label: i18n.t('IPv6 Prefix'),
          fields: [
            {
              key: 'ipv6_prefix',
              component: pfFormInput
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
                options: pfConfigurationInterfaceTypes
              }
            }
          ]
        },
        {
          label: i18n.t('Additional listening daemon(s)'),
          fields: [
            {
              key: 'additional_listening_daemons',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to add a daemon'),
                trackBy: 'value',
                label: 'text',
                multiple: true,
                allowEmpty: true,
                clearOnSelect: false,
                closeOnSelect: false,
                options: pfCongigurationInterfaceDaemons
              }
            }
          ]
        },
        {
          if: ['inlinel2'].includes(form.type),
          label: i18n.t('DNS'),
          text: i18n.t('The DNS server(s) of your network. (comma limited)'),
          fields: [
            {
              key: 'dns',
              component: pfFormInput
            }
          ]
        },
        {
          if: ['dns-enforcement', 'inlinel2', 'vlan-isolation', 'vlan-registration'].includes(form.type),
          label: i18n.t('Enable DHCP Server'),
          fields: [
            {
              key: 'dhcpd_enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: ['inlinel2'].includes(form.type),
          label: i18n.t('Enable NAT'),
          fields: [
            {
              key: 'nat_enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: ['inlinel2'].includes(form.type) && ~~form.nat_enabled === 0,
          label: null, /* no label */
          fields: [
            {
              component: pfFormHtml,
              attrs: {
                html: `<div class="alert alert-warning">
                  <strong>${i18n.t('Note')}</strong>
                  ${i18n.t('Since NATting mode is disabled, PacketFence will adjust iptables to rules to route traffic rather than NATting it. Make sure to add the routes on the system.')}
                </div>`
              }
            }
          ]
        },
        {
          if: ['inlinel2'].includes(form.type),
          label: i18n.t('Split network by role'),
          text: i18n.t('This will create a small network for each roles.'),
          fields: [
            {
              key: 'split_network',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: ['inlinel2'].includes(form.type),
          label: i18n.t('Registration IP Address CIDR format'),
          text: i18n.t('When split network by role is enabled then this network will be used as the registration network (example: 192.168.0.1/24).'),
          fields: [
            {
              key: 'reg_network',
              component: pfFormInput,
              validators: {
                [i18n.t('Invalid CIDR.')]: isCIDR
              }
            }
          ]
        },
        {
          if: ['inlinel2'].includes(form.type),
          label: null, /* no label */
          fields: [
            {
              component: pfFormHtml,
              attrs: {
                html: `<div class="alert alert-warning">
                  <strong>${i18n.t('Note')}</strong>
                  ${i18n.t('Remember to enable ip_forward on your operating system for the inline mode to work.')}
                </div>`
              }
            }
          ]
        },
        {
          if: ['none', 'management'].includes(form.type),
          label: i18n.t('High availability'),
          fields: [
            {
              key: 'high_availability',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: '1', unchecked: '0' }
              }
            }
          ]
        }
      ]
    }
  ]
}
