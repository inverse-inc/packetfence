import i18n from '@/utils/locale'

// Health of a connector: its tunnel, rolled up with the site services it runs
// (interfaces, routes, DHCP relays, captive DNS) and its high availability, as
// reported in pfconnector-remotes/{id}/status. Used by the list, the
// topology and the connector view so that they agree.

// a DHCP relay error this recent keeps the connector degraded even when the
// relay answered since
export const RELAY_ERROR_WINDOW = 15 * 60 * 1000

export const siteNetworkVariant = state => {
  switch (state) {
    case 'up':
    case 'applied':
      return 'success'
    case 'down':
      return 'warning'
    default:
      return 'danger'
  }
}

// The relay is failing when its last error is more recent than its last
// reply, or recent enough. Connectors predating the timestamps only report
// the last error ever seen, which tells nothing about now.
export const relayFailing = (relay, now = Date.now()) => {
  const { last_error_at: errorAt, last_reply_at: replyAt } = relay || {}
  if (!errorAt)
    return false
  const error = Date.parse(errorAt)
  return !replyAt || error > Date.parse(replyAt) || now - error < RELAY_ERROR_WINDOW
}

// What fails in the site networking of a connector (system of its status),
// as sentences.
export const siteNetworkIssues = (system, now = Date.now()) => {
  const {
    site_network: { interfaces = [], routes = [] } = {},
    dhcp_relay: relays,
    dns_server: servers
  } = system || {}
  return [
    ...(interfaces || []).filter(({ state }) => siteNetworkVariant(state) === 'danger')
      .map(({ name, cidr, error }) => i18n.t('Interface {name} ({cidr}): {error}', { name, cidr, error: error || i18n.t('failed') })),
    ...(routes || []).filter(({ state }) => siteNetworkVariant(state) === 'danger')
      .map(({ destination, error }) => i18n.t('Route to {destination}: {error}', { destination, error: error || i18n.t('failed') })),
    ...(Array.isArray(relays) ? relays : []).filter(relay => relay.state !== 'listening' || relayFailing(relay, now))
      .map(({ interface: name, error, last_error: lastError }) => i18n.t('DHCP relay on {name}: {error}', { name, error: error || lastError || i18n.t('not listening') })),
    ...(Array.isArray(servers) ? servers : []).filter(({ state }) => state !== 'listening')
      .map(({ interface: name, error }) => i18n.t('Captive DNS on {name}: {error}', { name, error: error || i18n.t('not listening') }))
  ]
}

// tunnel: 'up', 'down' or anything else (unknown); remote: the status of the
// connector-remote, null when not fetched. Returns { level, reasons } with
// level 'healthy', 'degraded', 'down' or 'unknown'.
export const connectorHealth = (tunnel, remote, now = Date.now()) => {
  if (tunnel === 'down')
    return { level: 'down', reasons: [i18n.t('The tunnel is inactive or the connector API does not answer.')] }
  if (tunnel !== 'up')
    return { level: 'unknown', reasons: [i18n.t('Not seen by the pfconnector server since it started, or the status is unavailable.')] }
  const { system } = remote || {}
  const { ha } = system || {}
  const peers = (ha && ha.enabled && ha.peers) || []
  const reasons = [
    ...siteNetworkIssues(system, now),
    ...((ha && ha.enabled && !peers.some(peer => peer.alive))
      ? [i18n.t('High availability: no standby host is reporting.')]
      : []),
    ...((ha && ha.enabled && ha.radius_ok === false)
      ? [i18n.t('Active host {host}: FreeRADIUS does not answer.', { host: ha.hostname || ha.address })]
      : []),
    // a standby host that could not take over
    ...peers.filter(peer => peer.alive && peer.radius_ok === false)
      .map(peer => i18n.t('Standby host {host}: FreeRADIUS does not answer.', { host: [peer.hostname, peer.address].filter(Boolean).join(' ') }))
  ]
  return { level: reasons.length ? 'degraded' : 'healthy', reasons }
}

export const healthVariant = level => ({ healthy: 'success', degraded: 'warning', down: 'danger' }[level] || 'secondary')

export const healthLabel = level => ({
  healthy: i18n.t('Healthy'),
  degraded: i18n.t('Degraded'),
  down: i18n.t('Unreachable')
}[level] || i18n.t('Unknown'))
