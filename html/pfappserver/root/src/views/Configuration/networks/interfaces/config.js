import i18n from '@/utils/locale'
import network from '@/utils/network'

export const types = {
  none:                 i18n.t('None'),
  'dhcp-listener':      i18n.t('DHCP Listener'),
  'dns-enforcement':    i18n.t('DNS Enforcement'),
  inlinel2:             i18n.t('Inline Layer 2'),
  management:           i18n.t('Management'),
  portal:               i18n.t('Portal'),
  'vlan-isolation':     i18n.t('Isolation'),
  'vlan-registration':  i18n.t('Registration'),
  other:                i18n.t('Other')
}

export const typeOptions = Object.keys(types)
  .sort((a, b) => types[a].localeCompare(types[b]))
  .map(key => ({ value: key, text: types[key] }))

export const typeFormatter = value => {
  if (value === null || value === '')
    return null
  if (value in types)
    return types[value]
  return i18n.t('Unknown')
}

export const daemons = {
  dhcp:             'dhcp',
  dns:              'dns',
  portal:           'portal',
  radius:           'radius',
  'dhcp-listener':  'dhcp-listener'
}

export const daemonOptions = Object.keys(daemons)
  .sort((a, b) => daemons[a].localeCompare(daemons[b]))
  .map(key => ({ value: key, text: daemons[key] }))

export const sortColumns = { // maintain hierarchical ordering (master => vlans)
  id: (itemA, itemB, sortDesc) => {
    const sortMod = (sortDesc) ? -1 : 1
    if (!itemA)
      return -1 * sortMod
    if (!itemB)
      return 1 * sortMod
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
    key: 'netmask',
    label: 'Netmask', // i18n defer
    sortable: true,
    visible: true,
    sort: sortColumns.netmask
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
    formatter: value => {
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
