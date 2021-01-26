import i18n from '@/utils/locale'
import network from '@/utils/network'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  and,
  not,
  conditional,
  ipv6Address,
  isCIDR,
  isVLAN,
  hasInterfaces,
  interfaceVlanExists
} from '@/globals/pfValidators'
import {
  required,
  ipAddress
} from 'vuelidate/lib/validators'

export const typesList = [
  { value: 'none', text: i18n.t('None') },
  { value: 'dhcp-listener', text: i18n.t('DHCP Listener') },
  { value: 'dns-enforcement', text: i18n.t('DNS Enforcement') },
  { value: 'inlinel2', text: i18n.t('Inline Layer 2') },
  { value: 'management', text: i18n.t('Management') },
  { value: 'portal', text: i18n.t('Portal') },
  { value: 'vlan-isolation', text: i18n.t('Isolation') },
  { value: 'vlan-registration', text: i18n.t('Registration') },
  { value: 'other', text: i18n.t('Other') }
]

export const daemonsList = [
  { value: 'dhcp', text: 'dhcp' },
  { value: 'dns', text: 'dns' },
  { value: 'portal', text: 'portal' },
  { value: 'radius', text: 'radius' },
  { value: 'dhcp-listener', text: 'dhcp-listener' }
]

export const typeFormatter = (value) => {
  if (value === null || value === '') return null
  let unknown = i18n.t('Unknown')
  const type = typesList.find(type => type.value === value)
  if (type) {
    const { text = unknown } = type
    return text
  }
  return unknown
}

export const sortColumns = { // maintain hierarchical ordering (master => vlans)
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

export const columns = [
  {
    key: 'is_running',
    label: 'Status', // i18n defer
    visible: true
  },
  {
    key: 'id',
    label: 'Logical Name', // i18n defer
    required: true,
    sortable: true,
    visible: true,
    sort: sortColumns.id
  },
  {
    key: 'ipaddress',
    label: 'IPv4 Address', // i18n defer
    sortable: true,
    visible: true,
    sort: sortColumns.ipaddress
  },
  {
    key: 'ipv6_address',
    label: 'IPv6 Address', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'ipv6_prefix',
    label: 'IPv6 Prefix', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'netmask',
    label: 'Netmask', // i18n defer
    sortable: true,
    visible: true,
    sort: sortColumns.netmask
  },
  {
    key: 'network',
    label: 'Default Network', // i18n defer
    sortable: true,
    visible: true,
    sort: sortColumns.network
  },
  {
    key: 'type',
    label: 'Type', // i18n defer
    visible: true,
    formatter: typeFormatter
  },
  {
    key: 'additional_listening_daemons',
    label: 'Daemons', // i18n defer
    visible: true,
    formatter: (value) => {
      if (value && value.constructor === Array && value.length > 0) {
        return value
      }
      return null // otherwise '[]' is displayed in cell
    }
  },
  {
    key: 'high_availability',
    label: 'High Availability', // i18n defer
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
    master = false,
    type
  } = form
  const {
    isNew = false,
    isClone = false,
    isVlan = false
  } = meta
  return [
    {
      tab: null,
      rows: [
        {
          if: (!master),
          label: i18n.t('Interface'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                disabled: true
              }
            }
          ]
        },
        {
          if: (master),
          label: i18n.t('Interface'),
          cols: [
            {
              namespace: 'master',
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
          cols: [
            {
              namespace: 'vlan',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1,
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('IPv4 Address'),
          cols: [
            {
              namespace: 'ipaddress',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Netmask'),
          cols: [
            {
              namespace: 'netmask',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('IPv6 Address'),
          cols: [
            {
              namespace: 'ipv6_address',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('IPv6 Prefix'),
          cols: [
            {
              namespace: 'ipv6_prefix',
              component: pfFormInput
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
                options: typesList
              }
            }
          ]
        },
        {
          label: i18n.t('Additional listening daemon(s)'),
          cols: [
            {
              namespace: 'additional_listening_daemons',
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
                options: daemonsList
              }
            }
          ]
        },
        {
          if: ['inlinel2'].includes(type),
          label: i18n.t('DNS'),
          text: i18n.t('The DNS server(s) of your network. (comma limited)'),
          cols: [
            {
              namespace: 'dns',
              component: pfFormInput
            }
          ]
        },
        {
          if: ['dns-enforcement', 'inlinel2', 'vlan-isolation', 'vlan-registration'].includes(type),
          label: i18n.t('Enable DHCP Server'),
          cols: [
            {
              namespace: 'dhcpd_enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: ['inlinel2'].includes(type),
          label: i18n.t('Enable NAT'),
          cols: [
            {
              namespace: 'nat_enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: ['inlinel2'].includes(type) && form.nat_enabled !== 'enabled',
          label: null, /* no label */
          cols: [
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
          if: ['inlinel2'].includes(type),
          label: i18n.t('Split network by role'),
          text: i18n.t('This will create a small network for each roles.'),
          cols: [
            {
              namespace: 'split_network',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: ['inlinel2'].includes(type),
          label: i18n.t('Registration IP Address CIDR format'),
          text: i18n.t('When split network by role is enabled then this network will be used as the registration network (example: 192.168.0.1/24).'),
          cols: [
            {
              namespace: 'reg_network',
              component: pfFormInput
            }
          ]
        },
        {
          if: ['inlinel2'].includes(type),
          label: null, /* no label */
          cols: [
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
          if: ['inlinel2'].includes(type),
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
          if: ['inlinel2'].includes(type),
          label: i18n.t('Netflow Accounting Enabled'),
          text: i18n.t('Enable Netflow on this network to enable accounting.'),
          cols: [
            {
              namespace: 'netflow_accounting_enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: ['none', 'management'].includes(type),
          label: i18n.t('High availability'),
          cols: [
            {
              namespace: 'high_availability',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 1, unchecked: 0 }
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
    type
  } = form
  const {
    isNew = false,
    isClone = false,
    isVlan = false,
    id = null
  } = meta
  return {
    ...((isNew || isClone || isVlan)
      ? {
        vlan: {
          [i18n.t('VLAN required.')]: required,
          [i18n.t('Invalid VLAN.')]: isVLAN,
          [i18n.t('VLAN exists.')]: not(and(required, conditional(isNew || isClone), hasInterfaces, interfaceVlanExists(id)))
        }
      }
      : {}
    ),
    ...{
      ipaddress: {
        [i18n.t('Invalid IPv4 address.')]: ipAddress
      },
      netmask: {
        [i18n.t('Invalid IPv4 address.')]: ipAddress
      },
      ipv6_address: {
        [i18n.t('Invalid IPv6 address.')]: ipv6Address
      }
    },
    ...((['inlinel2'].includes(type))
      ? {
        reg_network: {
          [i18n.t('Invalid CIDR.')]: isCIDR
        }
      }
      : {}
    )
  }
}
