import i18n from '@/utils/locale'
import { cidrToRange, ipv4ToInt } from '@/utils/network'

// Rows of the connector view tables, derived from the remote status
// (static_connections, bound_remotes) and the equipment located behind the
// connector. Names follow how the backend builds the forwards:
// lib/pfconfig/namespaces/resource/pfconnector_static_connections.pm and
// go/chisel/server/server_handler.go (fingerbank collector reverse bind,
// dynreverse callers).

export const equipmentGroups = [
  { key: 'switches', category: 'Switch', routeName: 'switch' }, // i18n defer
  { key: 'authentication_sources', category: 'Authentication source', routeName: 'source' }, // i18n defer
  // Domain UI ids are host-scoped section names, not the bare domain id
  // the config hash exposes: no reliable deep-link.
  { key: 'domains', category: 'AD domain', routeName: null }, // i18n defer
  { key: 'firewalls', category: 'Firewall SSO', routeName: 'firewall' }, // i18n defer
  // configured on the connector itself (Settings > DNS), listed as ip:port
  { key: 'dns_connectors', category: 'DNS server', routeName: null } // i18n defer
]

const ipv4Re = /^\d{1,3}(\.\d{1,3}){3}(\/\d{1,2})?$/

const toRange = cidrOrIp => {
  if (!ipv4Re.test(cidrOrIp))
    return null
  const [start, end] = cidrToRange(cidrOrIp)
  return [ipv4ToInt(start), ipv4ToInt(end)]
}

// The first connector network (in configuration order) that contains or
// overlaps one of the IPs. IPv4 only.
export const routedVia = (ips = [], networks = []) => {
  for (const network of networks) {
    const networkRange = toRange(network)
    if (!networkRange)
      continue
    for (const ip of ips) {
      const range = toRange(ip)
      if (range && range[0] <= networkRange[1] && networkRange[0] <= range[1])
        return network
    }
  }
  return null
}

export const equipmentRows = (equipment, networks) => {
  return equipmentGroups.reduce((rows, group) => {
    const { [group.key]: items = [] } = equipment || {}
    return [
      ...rows,
      ...items.map(item => ({
        ...item,
        group: group.key,
        category: i18n.t(group.category),
        routeName: group.routeName,
        ips: item.ips || [],
        routed_via: routedVia(item.ips || [], networks)
      }))
    ]
  }, [])
}

const findEquipment = (rows, host) => rows.find(row => row.ips.includes(host))

const staticServiceName = (connection, dnsConnectors, rows) => {
  const { local_port, local_proto, remote_host } = connection
  const dns = dnsConnectors.find(item => `${item.pfconnector_port}` === `${local_port}` && item.ip === remote_host)
  if (dns)
    return i18n.t('DNS server {id}', { id: `${dns.ip}:${dns.port}` })
  if (remote_host === '127.0.0.1' && local_proto === 'tcp')
    return i18n.t('NTLM auth API')
  if (local_proto === 'udp') {
    const source = rows.find(row => row.group === 'authentication_sources' && row.type === 'RADIUS' && row.ips.includes(remote_host))
    return (source)
      ? i18n.t('RADIUS source {id}', { id: source.id })
      : i18n.t('RADIUS source')
  }
  return null
}

const onDemandServiceName = (remote, rows) => {
  const { remote_host, remote_port } = remote
  switch (`${remote_host}:${remote_port}`) {
    case '127.0.0.1:4723': return i18n.t('Fingerbank collector')
    case '127.0.0.1:8081': return i18n.t('Connector API')
    case '100.64.0.1:23000': return i18n.t('NTLM domain join')
  }
  const device = findEquipment(rows, remote_host)
  return (device)
    ? `${device.category} ${device.id}`
    : null
}

export const tunnelRows = (status, dnsConnectors = [], rows = []) => {
  const {
    connected = false,
    static_connections: staticConnections = [],
    bound_remotes: boundRemotes = []
  } = status || {}
  const staticKeys = new Set((staticConnections || []).map(c => `${c.local_proto}:${c.local_port}`))
  return [
    ...(staticConnections || []).map(connection => ({
      ...connection,
      kind: i18n.t('Static'),
      service: staticServiceName(connection, dnsConnectors, rows),
      target: `${connection.remote_host}:${connection.remote_port}`,
      state: (connected)
        ? (connection.bound ? 'bound' : 'not_bound')
        : null
    })),
    ...(boundRemotes || [])
      .filter(remote => !staticKeys.has(`${remote.local_proto}:${remote.local_port}`))
      .map(remote => ({
        ...remote,
        kind: i18n.t('On demand'),
        service: onDemandServiceName(remote, rows),
        target: `${remote.remote_host}:${remote.remote_port}`,
        state: 'bound'
      }))
  ]
}

// Bound state of the static connections matching { port, host, proto }
// (tcp and udp for a DNS server): 'bound', 'partial', 'not_bound' or null.
export const staticState = (status, { port, host, proto } = {}) => {
  const { connected = false, static_connections: connections = [] } = status || {}
  if (!connected)
    return null
  const matches = (connections || []).filter(c => (
    (port === undefined || `${c.local_port}` === `${port}`) &&
    (host === undefined || c.remote_host === host) &&
    (proto === undefined || c.local_proto === proto)
  ))
  if (!matches.length)
    return null
  const bound = matches.filter(c => c.bound).length
  if (bound === matches.length)
    return 'bound'
  return (bound) ? 'partial' : 'not_bound'
}

export const stateBadge = state => {
  switch (state) {
    case 'bound': return { variant: 'success', label: i18n.t('bound') }
    case 'partial': return { variant: 'warning', label: i18n.t('partially bound') }
    case 'not_bound': return { variant: 'danger', label: i18n.t('not bound') }
    default: return null
  }
}

const networkRange = network => (ipv4Re.test(network) ? toRange(network) : null)

// High availability of a connector, as reported by its active host in
// pfconnector-remotes/{id}/status (system.ha): the hosts share the connector
// id and the VIP, the one holding the VIP (master) runs the tunnel and the
// standby hosts report to it. null when HA is off or not reported.
export const connectorHa = status => {
  const { system: { ha } = {} } = status || {}
  if (!ha || !ha.enabled)
    return null
  const peers = (ha.peers || []).map(peer => ({ ...peer, alive: !!peer.alive }))
  return {
    vip: ha.vip,
    hostname: ha.hostname,
    address: ha.address,
    state: ha.state,
    peers,
    alive: peers.filter(peer => peer.alive).length
  }
}

// host:port values an equipment item is reached on through the connector,
// taken from the connector's tunnel forwards of the protocol its kind uses
// (RADIUS sources over udp, AD/LDAP and firewalls over tcp); the IPs alone
// when none match
const ENDPOINT_PROTOS = {
  authentication_sources: row => (row.type === 'RADIUS' ? ['udp'] : ['tcp']),
  domains: () => ['tcp'],
  firewalls: () => ['tcp']
}
export const equipmentEndpoints = (row, status) => {
  const {
    static_connections: staticConnections = [],
    bound_remotes: boundRemotes = []
  } = status || {}
  const protos = (ENDPOINT_PROTOS[row.group] || (() => null))(row)
  const endpoints = [...(staticConnections || []), ...(boundRemotes || [])]
    .filter(forward => row.ips.includes(forward.remote_host) && (!protos || protos.includes(forward.local_proto)))
    .map(forward => `${forward.remote_host}:${forward.remote_port}/${forward.local_proto}`)
  const unique = [...new Set(endpoints)]
  return (unique.length) ? unique : row.ips
}

// IPv4 networks in address order, then the others
export const sortNetworks = (networks = []) => [...networks].sort((a, b) => {
  const rangeA = networkRange(a)
  const rangeB = networkRange(b)
  if (rangeA && rangeB)
    return (rangeA[0] - rangeB[0]) || (rangeA[1] - rangeB[1])
  if (rangeA)
    return -1
  if (rangeB)
    return 1
  return a.localeCompare(b)
})

// Interface reaching an IP or a network: the one with an address in a subnet
// containing or overlapping it (local: true), else the default route one
// (main), or null.
// interfaces: [{ name, cidrs: ['10.0.0.237/24'], main }]
const overlaps = (a, b) => a && b && a[0] <= b[1] && b[0] <= a[1]
export const interfaceFor = (ipOrNetwork, interfaces = []) => {
  const range = toRange(ipOrNetwork)
  const match = range && interfaces.find(({ cidrs = [] }) => cidrs.some(cidr => overlaps(toRange(cidr), range)))
  if (match)
    return { name: match.name, main: !!match.main, local: true }
  const main = interfaces.find(({ main }) => main)
  return (main) ? { name: main.name, main: true, local: false } : null
}

// Interfaces of a connector host, as reported by the connectors that
// support it (system.host_interfaces), else []
export const connectorInterfaces = status => {
  const { system: { host_interfaces: interfaces = [] } = {} } = status || {}
  return (interfaces || [])
    .filter(({ up }) => up !== false)
    .map(({ name, addresses = [], main }) => ({ name, cidrs: (addresses || []).filter(cidr => ipv4Re.test(cidr)), main }))
}

// PacketFence interfaces (config/interfaces); no default route is known
export const packetfenceInterfaces = (items = []) => (items || [])
  .filter(({ ipaddress, netmask }) => ipaddress && netmask)
  .map(({ id, name, ipaddress, netmask, type }) => {
    const bits = ipv4ToInt(netmask).toString(2).replace(/0/g, '').length
    return { name: name || id, cidrs: [`${ipaddress}/${bits}`], type: type || '' }
  })
