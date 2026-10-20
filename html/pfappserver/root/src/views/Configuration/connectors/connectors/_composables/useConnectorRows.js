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
  { key: 'dns_connectors', category: 'DNS server', routeName: 'connectorsDn' } // i18n defer
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
    return i18n.t('DNS server {id}', { id: dns.id })
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
