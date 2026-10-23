import i18n from '@/utils/locale'
import { routedVia } from './useConnectorRows'

// DNS forwarding through the connectors, as the backend builds it:
// - the tunnel of a DNS server is the first connector (configuration order)
//   with a network containing its IP, else none: PacketFence queries it
//   directly (find_connector, local_connector in
//   lib/pfconfig/namespaces/resource/pfconnector_static_connections.pm)
// - a domain is forwarded (conf/pfdns-connector.conf) only when it is
//   declared on a connector (domains_connectors) and listed by a DNS server

const listify = value => {
  if (Array.isArray(value))
    return value.filter(Boolean)
  return `${value || ''}`.split(',').map(v => v.trim()).filter(Boolean)
}

// connectors: [{ id, networks }] in configuration order
export const dnsOwner = (ip, connectors = []) => {
  for (const connector of connectors) {
    if (routedVia([ip], connector.networks || []))
      return connector.id
  }
  return null
}

// { servers: { [id]: server }, issues: { [connector id]: [issue] }, direct: [server], declared: { [domain]: connector } }
// server: { id, ip, port, pfconnector_port, owner, domains, chips: [{ domain, state, tooltip }] }
// Only the forwarded domains are shown. chip state: 'ok', or 'elsewhere'
// (declared on another connector than the one reaching the server,
// forwarded anyway)
export const dnsTopology = (connectors = [], dnsServers = [], dnsDomains = []) => {
  const declared = dnsDomains.reduce((declared, { id, connector }) => ({ ...declared, [id]: connector }), {})
  const known = new Set(connectors.map(connector => connector.id))
  const servers = {}
  const issues = {}
  const direct = []
  const addIssue = (connector, issue) => {
    issues[connector] = [...(issues[connector] || []), issue]
  }
  const listedBy = {}

  dnsServers.forEach(dns => {
    const owner = dnsOwner(dns.ip, connectors)
    // a domain without a connector declaration is not forwarded
    const domains = listify(dns.domains).filter(domain => known.has(declared[domain]))
    const chips = domains.map(domain => {
      listedBy[domain] = [...(listedBy[domain] || []), { id: dns.id, owner }]
      const on = declared[domain]
      if (owner && on !== owner)
        return { domain, state: 'elsewhere', tooltip: i18n.t('{domain}: declared on {declared}, forwarded through {owner} ({ip})', { domain, declared: on, owner, ip: dns.ip }) }
      return { domain, state: 'ok', tooltip: i18n.t('{domain}: forwarded to {id} ({ip})', { domain, id: dns.id, ip: dns.ip }) }
    })
    const server = { ...dns, owner, domains, chips }
    servers[dns.id] = server
    if (!owner)
      direct.push(server)
  })

  Object.keys(declared).forEach(domain => {
    const on = declared[domain]
    const to = { name: 'connectorsDomain', params: { id: domain } }
    const by = listedBy[domain] || []
    if (!by.length || !known.has(on)) // not forwarded
      return
    const through = [...new Set(by.map(({ owner }) => owner).filter(owner => owner && owner !== on))]
    if (through.length)
      addIssue(on, { domain, state: 'elsewhere', label: i18n.t('declared here, forwarded through {owners}', { owners: through.join(', ') }), to })
    else
      addIssue(on, { domain, state: 'ok', label: i18n.t('forwarded to {servers}', { servers: by.map(({ id }) => id).join(', ') }), to })
  })

  return { servers, issues, direct, declared }
}

// pages through a config collection (the list endpoints default to 25 items)
export const listAll = (list, cursor = 0, items = []) => list({ limit: 1000, cursor })
  .then(({ items: page = [], nextCursor }) => (nextCursor)
    ? listAll(list, nextCursor, [...items, ...page])
    : [...items, ...page]
  )
