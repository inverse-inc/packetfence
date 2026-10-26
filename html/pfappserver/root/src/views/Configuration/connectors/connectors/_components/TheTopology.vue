<template>
  <div ref="wrapperRef" class="connector-topology" :style="{ width: '100%', position: 'relative' }">
    <svg v-if="layout.nodes.length > 1"
      :width="layout.width" :height="layout.height" :viewBox="`0 0 ${layout.width} ${layout.height}`"
      :style="{ display: 'block', fill: 'none', overflow: 'visible' }"
      role="img" :aria-label="$i18n.t('Cloud connectors topology')">

      <!-- flow lines: right angles only -->
      <path v-for="edge in layout.edges" :key="edge.key" :d="edge.d"
        :style="{ fill: 'none', stroke: edge.color, strokeWidth: (related && related.edges.has(edge.key)) ? 2 : 1.5, strokeOpacity: (related && !related.edges.has(edge.key)) ? FADED * edge.opacity : edge.opacity, transition: 'stroke-opacity 150ms', strokeDasharray: edge.dashed ? '5 4' : 'none', strokeLinejoin: 'miter', strokeLinecap: 'square' }" />

      <g v-for="node in layout.nodes" :key="node.key"
        :style="{ cursor: 'pointer', outline: 'none', opacity: (related && !related.nodes.has(node.key)) ? FADED : 1, transition: 'opacity 150ms' }" tabindex="0" role="link"
        @mouseenter="hovered = node.key" @mouseleave="hovered = null"
        @focus="hovered = node.key" @blur="hovered = null"
        @click="goTo(node.to)" @keydown.enter="goTo(node.to)">
        <title>{{ node.tooltip }}</title>
        <!-- box -->
        <rect :x="node.x" :y="node.y" :width="node.w" :height="nodeHeight" rx="6"
          :style="{ fill: node.fill, stroke: hovered === node.key ? colors.primary : node.border, strokeWidth: hovered === node.key ? 2 : 1 }" />
        <!-- type accent -->
        <rect :x="node.x" :y="node.y" width="5" :height="nodeHeight" rx="2" :style="{ fill: node.accent, stroke: 'none' }" />
        <!-- type icon -->
        <g v-if="node.icon" :transform="`translate(${node.x + 14} ${node.y + (nodeHeight - iconSize) / 2}) scale(${iconSize / node.icon.size})`">
          <path v-for="(d, i) in node.icon.paths" :key="i" :d="d" :style="{ fill: node.iconColor, stroke: 'none' }" />
        </g>
        <!-- connected dot on the icon -->
        <circle v-if="node.dot" :cx="node.x + 14 + iconSize" :cy="node.y + (nodeHeight - iconSize) / 2 + 2" r="5"
          :style="{ fill: node.dot, stroke: node.fill, strokeWidth: 2 }" />
        <text :x="node.x + textX" :y="node.y + 18" :style="{ fill: node.titleColor, fontSize: '13px', fontWeight: 600, fontFamily: node.mono ? monoFont : 'inherit', stroke: 'none' }">{{ node.title }}<tspan v-if="node.titleExtra && node.titleExtra.length > 3" dx="6" :style="{ fill: node.subtitleColor, fontSize: '12px', fontWeight: 400 }">{{ node.titleExtra }}</tspan></text>
        <text :x="node.x + textX" :y="node.y + 34" :style="{ fill: node.subtitleColor, fontSize: '11px', stroke: 'none' }">{{ node.subtitle }}</text>
        <!-- DNS domain issues of a connector, detailed in its menu -->
        <g v-if="node.issues" @click.stop="openMenu(node)" @keydown.enter.stop="openMenu(node)">
          <title>{{ node.issues.tooltip }}</title>
          <rect :x="node.x + node.w - 26 - node.issues.w" :y="node.y + 25" :width="node.issues.w" height="14" rx="7"
            :style="{ fill: colors.orange, stroke: 'none' }" />
          <text :x="node.x + node.w - 26 - node.issues.w / 2" :y="node.y + 35" text-anchor="middle"
            :style="{ fill: colors.white, fontSize: '10px', fontWeight: 700, stroke: 'none' }">{{ node.issues.label }}</text>
        </g>
        <!-- master / slave pill -->
        <g v-if="node.badge">
          <rect :x="node.x + node.w - node.badge.w - node.badgeRight" :y="node.y + 7" :width="node.badge.w" height="16" rx="8" :style="{ fill: node.badge.color, stroke: 'none' }" />
          <text :x="node.x + node.w - node.badge.w / 2 - node.badgeRight" :y="node.y + 19" text-anchor="middle"
            :style="{ fill: colors.white, fontSize: '10px', fontWeight: 700, letterSpacing: '0.4px', stroke: 'none' }">{{ node.badge.label }}</text>
        </g>
        <!-- actions menu (3 dots) -->
        <g v-if="node.kind === 'connector'" @click.stop="openMenu(node)" @keydown.enter.stop="openMenu(node)">
          <title>{{ $i18n.t('Actions') }}</title>
          <rect :x="node.x + node.w - 26" :y="node.y + 4" width="22" :height="nodeHeight - 8" rx="4"
            :style="{ fill: menu && menu.key === node.key ? colors.light : 'transparent', stroke: 'none' }" />
          <g :transform="`translate(${node.x + node.w - 19} ${node.y + (nodeHeight - 16) / 2}) scale(${16 / menuIcon.size})`">
            <path v-for="(d, i) in menuIcon.paths" :key="i" :d="d" :style="{ fill: node.titleColor, stroke: 'none' }" />
          </g>
        </g>
      </g>
    </svg>
    <div v-if="menu" ref="menuRef" class="dropdown-menu show" role="menu"
      :style="{ position: 'absolute', left: `${menu.left}px`, top: `${menu.top}px`, right: 'auto' }">
      <h6 class="dropdown-header">{{ menu.name }}</h6>
      <template v-for="item in menu.items">
        <h6 v-if="item.header" :key="item.key" class="dropdown-header">{{ item.header }}</h6>
        <a v-else :key="item.key" href="javascript:void(0)" role="menuitem"
          class="dropdown-item" :class="{ disabled: item.disabled, 'text-danger': item.danger && !item.disabled, 'text-warning': item.warning }"
          :title="item.disabled ? item.reason : (item.tooltip || '')"
          @click.stop="!item.disabled && onMenuItem(item)">
          <icon :name="item.icon" class="mr-2" />{{ item.label }}<small v-if="item.detail" class="d-block text-muted ml-4">{{ item.detail }}</small>
        </a>
      </template>
    </div>
    <base-table-empty v-if="layout.nodes.length <= 1" :is-loading="isLoading">{{ $i18n.t('No cloud connector configured.') }}</base-table-empty>
  </div>
</template>
<script>
import { computed, onBeforeUnmount, onMounted, ref } from '@vue/composition-api'
import Icon from 'vue-awesome/components/Icon'
import { BaseTableEmpty } from '@/components/new/'
import { useResizeObserver } from '@/composables/useDom'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import { connectorHa, connectorInterfaces, equipmentEndpoints, equipmentRows, interfaceFor, packetfenceInterfaces, sortNetworks, staticState } from '../_composables/useConnectorRows'
import { dnsTopology } from '../_composables/useDnsTopology'

const components = {
  BaseTableEmpty
}

const NODE_HEIGHT = 44
const ROW_HEIGHT = 56
const PAD = 2
const ICON_SIZE = 18
const TEXT_X = 42
const FADED = 0.2 // opacity of the boxes and lines not related to the hovered box
const GUTTER_PAD = 8
const LANE_GAP = 6
const MAX_LANES = 3
const MAX_DOMAINS = 5
const CHAR_WIDTH = { title: 7.4, subtitle: 6.2, chip: 5.8 } // 13px / 11px / 10px text
const MONO_FONT = 'SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace'

// icons registered in main.js, by node kind / equipment group
const ICONS = {
  packetfence: 'shield-alt',
  network: 'project-diagram',
  connector: 'plug',
  switches: 'sitemap',
  authentication_sources: 'user-lock',
  domains: 'id-card',
  firewalls: 'lock',
  dns_connectors: 'server',
  dns_domain: 'globe'
}

// bootstrap CSS variables, read from the page with fallbacks
const COLOR_VARS = {
  primary: ['--primary', '#007bff'],
  success: ['--success', '#28a745'],
  danger: ['--danger', '#dc3545'],
  secondary: ['--secondary', '#6c757d'],
  dark: ['--dark', '#343a40'],
  white: ['--white', '#ffffff'],
  light: ['--light', '#f8f9fa'],
  gray: ['--gray', '#6c757d'],
  teal: ['--teal', '#20c997'],
  blue: ['--blue', '#007bff'],
  purple: ['--purple', '#6f42c1'],
  indigo: ['--indigo', '#6610f2'],
  orange: ['--orange', '#fd7e14'],
  cyan: ['--cyan', '#17a2b8']
}
const readColors = () => {
  const style = (typeof window !== 'undefined') ? window.getComputedStyle(document.documentElement) : null
  return Object.keys(COLOR_VARS).reduce((colors, key) => {
    const [cssVar, fallback] = COLOR_VARS[key]
    const value = style && style.getPropertyValue(cssVar).trim()
    return { ...colors, [key]: value || fallback }
  }, {})
}

const iconData = name => {
  const icon = Icon.icons[name]
  if (!icon)
    return null
  return { size: Math.max(icon.width, icon.height), paths: icon.paths.map(path => path.d) }
}

const props = {
  // connectors with their tunnel status: [{ id, description, networks, status }]
  items: {
    type: Array,
    default: () => ([])
  },
  // pfconnector-remotes/{id}/status of the connected connectors, by id
  remoteInfo: {
    type: Object,
    default: () => ({})
  },
  // config/connector/{id}/equipment, by id
  equipment: {
    type: Object,
    default: () => ({})
  },
  // config/connectors (configuration order), with the DNS servers and the
  // domains configured on them (dnsServersOf)
  dns: {
    type: Object,
    default: () => ({ connectors: [], servers: [], domains: [] })
  },
  // config/interfaces
  interfaces: {
    type: Array,
    default: () => ([])
  },
  // cloud: the PacketFence interfaces are pod interfaces, not shown
  saas: {
    type: Boolean
  },
  version: {
    type: String
  },
  isLoading: {
    type: Boolean
  }
}

const fit = (text, width, kind = 'title') => {
  const value = `${text || ''}`
  const max = Math.max(4, Math.floor(width / CHAR_WIDTH[kind]))
  return (value.length > max) ? `${value.slice(0, max - 1)}…` : value
}

// width of a pill label (10px text)
const chipWidth = label => Math.ceil(label.length * CHAR_WIDTH.chip) + 12

// right-angle route: out to the trunk, along it, then in to the target
const route = (x1, y1, x2, y2, trunkX) => (Math.abs(y2 - y1) < 1)
  ? `M${x1} ${y1} H${x2}`
  : `M${x1} ${y1} H${trunkX} V${y2} H${x2}`

const setup = (props, context) => {
  const { root: { $router } = {} } = context

  const colors = readColors()
  const hovered = ref(null)

  const wrapperRef = ref(null)
  const width = ref(0)
  useResizeObserver(wrapperRef, entries => {
    const [entry] = entries
    width.value = Math.floor(entry.contentRect.width)
  })

  // connected: green dot; anything else is disconnected: red dot, greyed box
  const statusColor = status => (status === 'up') ? colors.success : colors.danger

  const layout = computed(() => {
    const W = Math.max(width.value, 760)
    const gap = Math.max(36, Math.round(W * 0.04))
    // DNS servers and domains declared through the connectors, their tunnel
    const dnsInfo = dnsTopology(props.dns.connectors, props.dns.servers, props.dns.domains)
    const hasDomains = Object.values(dnsInfo.servers).some(server => server.chips.length)
    // right gutter for the DNS server -> domain brackets, one lane per server
    const gutter = (hasDomains) ? GUTTER_PAD + (MAX_LANES * LANE_GAP) : 0
    const available = W - (2 * PAD) - (3 * gap) - gutter
    // identical boxes in every column
    const boxW = Math.floor(available / 4)
    const pfX = PAD
    const connX = pfX + boxW + gap
    const netX = connX + boxW + gap
    const devX = netX + boxW + gap
    const rowY = row => PAD + (row * ROW_HEIGHT)
    const mid = node => node.y + (NODE_HEIGHT / 2)

    // PacketFence -> connectors -> networks -> devices, one band per
    // connector (connectors never share a network). An HA connector is one
    // entry with several hosts sharing its id and VIP: the master runs the
    // tunnel, the standby hosts it reports (system.ha.peers) are drawn under
    // it. A child is drawn on its parent's row, its siblings below.
    const firstNetwork = item => sortNetworks(item.networks || [])[0]
    const connectors = [...props.items].sort((a, b) => {
      const [na, nb] = [firstNetwork(a), firstNetwork(b)]
      if (na !== nb) {
        if (!na) return 1
        if (!nb) return -1
        return (sortNetworks([na, nb])[0] === na) ? -1 : 1
      }
      return a.id.localeCompare(b.id)
    })
    const tunnelColor = { bound: colors.success, partial: colors.orange, not_bound: colors.danger }
    const deviceAccent = { switches: 'blue', authentication_sources: 'purple', domains: 'indigo', firewalls: 'orange', dns_connectors: 'cyan' }

    const nodes = []
    const edges = []
    let row = 0

    // the connectors' tunnels end on the management interface
    const pfInterfaces = (props.saas) ? [] : packetfenceInterfaces(props.interfaces)
    const management = pfInterfaces.find(({ type }) => /management/.test(type))
    const viaInterface = iface => (!iface)
      ? null
      : ((iface.local) ? i18n.t('via {name}', { name: iface.name }) : i18n.t('via {name} (default route)', { name: iface.name }))

    // tunnel state of a group of DNS servers: bound, partial, not_bound or null
    const tunnelOf = (servers, remote) => {
      const states = servers.map(server => staticState(remote, { port: server.pfconnector_port, host: server.ip })).filter(Boolean)
      if (!states.length)
        return null
      if (states.every(state => state === 'bound'))
        return 'bound'
      return (states.some(state => state !== 'not_bound')) ? 'partial' : 'not_bound'
    }

    // "DNS forwarding" block of a band: a box in the network column, one box
    // per domain forwarded through the band, brackets from the DNS servers
    // (serverNodes, by id) to their domains. Returns the rows used.
    // the DNS servers of a connector are configured in its settings
    const dnsSettings = owner => (owner)
      ? { name: 'connectorsConnector', params: { id: owner }, query: { tab: 'settings', section: 'dns' } }
      : { name: 'connectorsConnectors' }
    const dnsBlock = ({ key, owner, source, trunkX, startRow, serverNodes, remote, connected, edgeStyle }) => {
      const servers = Object.values(dnsInfo.servers).filter(server => server.owner === owner && server.chips.length)
      if (!servers.length)
        return 0
      const domains = []
      servers.forEach(server => server.chips.forEach(chip => {
        let domain = domains.find(({ id }) => id === chip.domain)
        if (!domain) {
          domain = { id: chip.domain, state: chip.state, servers: [] }
          domains.push(domain)
        }
        domain.servers.push(server)
        if (chip.state === 'elsewhere')
          domain.state = 'elsewhere'
      }))
      // domains forwarded elsewhere than declared first, then the ones
      // served by several servers, then by name
      domains.sort((a, b) => ((b.state === 'elsewhere') - (a.state === 'elsewhere')) || (b.servers.length - a.servers.length) || a.id.localeCompare(b.id))
      const shown = (domains.length > MAX_DOMAINS) ? domains.slice(0, MAX_DOMAINS - 1) : domains
      const hidden = domains.length - shown.length
      const muted = !connected && owner
      const block = {
        key: `dns-${key}`, kind: 'network',
        x: netX, y: rowY(startRow), w: boxW,
        fill: muted ? colors.light : colors.white, border: colors.gray, accent: colors.cyan,
        icon: iconData(ICONS.dns_domain), iconColor: muted ? colors.secondary : colors.dark,
        titleColor: muted ? colors.secondary : colors.dark, subtitleColor: colors.secondary,
        title: fit(i18n.t('DNS forwarding'), boxW - TEXT_X - 8),
        subtitle: fit(i18n.t('{domains} domain(s) · {servers} server(s)', { domains: domains.length, servers: servers.length }), boxW - TEXT_X - 8, 'subtitle'),
        tooltip: domains.map(({ id }) => id).join(', '),
        to: dnsSettings(owner)
      }
      nodes.push(block)
      edges.push({ key: `edge-${block.key}`, from: source.key, to: block.key, ...edgeStyle, d: route(source.x + source.w, mid(source), block.x, mid(block), trunkX) })
      const domainNodes = {}
      shown.forEach((domain, index) => {
        const tunnel = (connected && remote) ? tunnelOf(domain.servers, remote) : null
        const via = i18n.t('via {servers}', { servers: domain.servers.map(({ id }) => id).join(', ') })
        const declared = (dnsInfo.declared || {})[domain.id]
        const node = {
          key: `dns-${key}-${domain.id}`, kind: 'device',
          x: devX, y: rowY(startRow + index), w: boxW,
          fill: muted ? colors.light : colors.white, border: colors.gray,
          accent: (domain.state === 'elsewhere') ? colors.orange : colors.cyan,
          icon: iconData(ICONS.dns_domain), iconColor: muted ? colors.secondary : colors.dark, dot: tunnelColor[tunnel],
          titleColor: muted ? colors.secondary : colors.dark, subtitleColor: colors.secondary,
          title: fit((domain.state === 'elsewhere') ? `! ${domain.id}` : domain.id, boxW - TEXT_X - 8),
          subtitle: fit([(domain.state === 'elsewhere') && i18n.t('declared on {connector}', { connector: declared }), via, tunnel && tunnel.replace('_', ' ')].filter(Boolean).join(' · '), boxW - TEXT_X - 8, 'subtitle'),
          tooltip: [i18n.t('DNS domain'), domain.id, via, (domain.state === 'elsewhere') && i18n.t('declared on {connector}, forwarded through this tunnel', { connector: declared }), tunnel && i18n.t('tunnel {state}', { state: tunnel.replace('_', ' ') })].filter(Boolean).join(' · '),
          to: dnsSettings(owner)
        }
        nodes.push(node)
        domainNodes[domain.id] = node
        edges.push({ key: `edge-${node.key}`, from: block.key, to: node.key, ...edgeStyle, d: route(block.x + block.w, mid(block), node.x, mid(node), block.x + block.w + gap / 2) })
      })
      if (hidden) {
        const node = {
          key: `dns-${key}-more`, kind: 'device',
          x: devX, y: rowY(startRow + shown.length), w: boxW,
          fill: colors.light, border: colors.gray, accent: colors.secondary,
          icon: iconData(ICONS.dns_domain), iconColor: colors.secondary,
          titleColor: colors.secondary, subtitleColor: colors.secondary,
          title: fit(i18n.t('+{count} more domains', { count: hidden }), boxW - TEXT_X - 8),
          subtitle: fit(domains.slice(shown.length).map(({ id }) => id).join(', '), boxW - TEXT_X - 8, 'subtitle'),
          tooltip: domains.slice(shown.length).map(({ id }) => id).join(', '),
          to: dnsSettings(owner)
        }
        nodes.push(node)
        edges.push({ key: `edge-${node.key}`, from: block.key, to: node.key, ...edgeStyle, d: route(block.x + block.w, mid(block), node.x, mid(node), block.x + block.w + gap / 2) })
      }
      // brackets in the right gutter, one lane per DNS server drawn in the
      // band with a domain shown
      servers.filter(server => serverNodes[server.id] && server.chips.some(({ domain }) => domainNodes[domain])).slice(0, MAX_LANES).forEach((server, lane) => {
        const from = serverNodes[server.id]
        const laneX = devX + boxW + GUTTER_PAD + (lane * LANE_GAP)
        server.chips.forEach(({ domain }) => {
          const to = domainNodes[domain]
          if (to)
            edges.push({
              key: `bracket-${key}-${server.id}-${domain}`, from: from.key, to: to.key, bracket: true, color: colors.cyan, opacity: 0.8, dashed: true,
              d: `M${from.x + from.w} ${mid(from)} H${laneX} V${mid(to)} H${to.x + to.w}`
            })
        })
      })
      return shown.length + (hidden ? 1 : 0)
    }

    const packetfence = {
      key: 'packetfence', kind: 'packetfence',
      x: pfX, y: rowY(0), w: boxW,
      fill: colors.primary, border: colors.primary, accent: colors.primary,
      icon: iconData(ICONS.packetfence), iconColor: colors.white,
      titleColor: colors.white, subtitleColor: colors.light,
      title: fit('PacketFence', boxW - TEXT_X - 8),
      subtitle: fit([props.version && i18n.t('version {version}', { version: props.version }), management && management.name].filter(Boolean).join(' · '), boxW - TEXT_X - 8, 'subtitle'),
      tooltip: [props.version ? `PacketFence ${props.version}` : 'PacketFence', management && i18n.t('tunnels on {name} (management)', { name: management.name })].filter(Boolean).join(' · '),
      to: { path: '/status/about' }
    }
    nodes.push(packetfence)
    const pfTrunk = packetfence.x + packetfence.w + gap / 2

    connectors.forEach(connector => {
      const bandStart = row
      const remote = props.remoteInfo[connector.id]
      const { system } = remote || {}
      const version = system && system.version
      const ha = connectorHa(remote)
      const status = connector.status || 'unknown'
      const connected = status === 'up'
      const statusLabel = { up: i18n.t('connected'), down: i18n.t('unreachable') }[status] || i18n.t('unknown')
      const badgeLabel = ha ? i18n.t('master').toUpperCase() : null
      const badge = ha ? { label: badgeLabel, w: Math.max(46, badgeLabel.length * 7 + 14), color: colors.success } : null
      // interfaces of the connector host, when it reports them, else its
      // default route IPs (remote_ips)
      const hostInterfaces = connectorInterfaces(remote)
      const mainInterface = hostInterfaces.find(({ main }) => main)
      const [uplinkIp] = (remote && remote.remote_ips) || []
      const uplink = [mainInterface && mainInterface.name, uplinkIp].filter(Boolean).join(' ')
      const dnsDomains = dnsInfo.issues[connector.id] || []
      const dnsIssues = dnsDomains.filter(issue => issue.state !== 'ok')
      const issuesLabel = `! ${dnsIssues.length}`
      const issues = (dnsIssues.length)
        ? { label: issuesLabel, w: chipWidth(issuesLabel), tooltip: i18n.t('{count} DNS domain issue(s), see the actions menu', { count: dnsIssues.length }) }
        : null
      // named by its description, the identifier when it has none, next to
      // the hostname of the host running the tunnel
      const name = connector.description || connector.id
      const hostname = (ha && ha.hostname) || (system && system.hostname)
      const titleWidth = boxW - TEXT_X - 32 - (badge ? badge.w + 8 : 0)
      const hostnameWidth = titleWidth - ((name.length + 1) * CHAR_WIDTH.title)
      const head = {
        key: `connector-${connector.id}`, kind: 'connector', id: connector.id, name,
        x: connX, y: rowY(bandStart), w: boxW,
        fill: connected ? colors.white : colors.light, border: colors.gray, accent: connected ? colors.success : colors.secondary,
        icon: iconData(ICONS.connector), iconColor: connected ? colors.dark : colors.secondary, dot: statusColor(status),
        titleColor: connected ? colors.dark : colors.secondary, subtitleColor: colors.secondary, badge,
        badgeRight: 32,
        title: fit(name, titleWidth),
        titleExtra: (hostname && hostnameWidth >= 6 * CHAR_WIDTH.subtitle) ? fit(hostname, hostnameWidth, 'subtitle') : '',
        subtitle: fit([statusLabel, ha ? `VIP ${ha.vip}` : null, uplink, version].filter(Boolean).join(' · '), boxW - TEXT_X - 32 - (issues ? issues.w + 4 : 0), 'subtitle'),
        tooltip: [connector.description, connector.id, !ha && hostname, statusLabel, version, ha && `VIP ${ha.vip}`, ha && `${ha.hostname || ''} ${ha.address || ''}`.trim(), uplink && i18n.t('uplink {uplink}', { uplink })].filter(Boolean).join(' · '),
        to: { name: 'connectorsConnector', params: { id: connector.id } },
        status, connected, networks: connector.networks || [], issues, dnsDomains
      }
      nodes.push(head)
      edges.push({
        key: `edge-pf-${head.key}`, from: packetfence.key, to: head.key, color: connected ? colors.success : colors.secondary, opacity: connected ? 0.7 : 0.6,
        dashed: !connected,
        d: route(packetfence.x + packetfence.w, mid(packetfence), head.x, mid(head), pfTrunk)
      })
      const bandTrunk = head.x + head.w + gap / 2

      // standby hosts of an HA connector, joined to the master's trunk
      const standby = (ha ? ha.peers : []).map((peer, index) => {
        const label = peer.hostname || peer.address
        const node = {
          key: `standby-${connector.id}-${peer.address || index}`, kind: 'standby',
          x: connX, y: rowY(bandStart + 1 + index), w: boxW,
          fill: peer.alive ? colors.white : colors.light, border: colors.gray, accent: peer.alive ? colors.secondary : colors.secondary,
          icon: iconData(ICONS.connector), iconColor: colors.secondary, dot: peer.alive ? colors.success : colors.danger,
          titleColor: peer.alive ? colors.dark : colors.secondary, subtitleColor: colors.secondary,
          badge: { label: i18n.t('standby').toUpperCase(), w: Math.max(56, i18n.t('standby').length * 7 + 14), color: colors.secondary },
          badgeRight: 8,
          title: fit(label, boxW - TEXT_X - 72),
          subtitle: fit([peer.alive ? i18n.t('reporting') : i18n.t('not reporting'), peer.address, peer.version].filter(Boolean).join(' · '), boxW - TEXT_X - 8, 'subtitle'),
          tooltip: [label, peer.address, peer.version, peer.alive ? i18n.t('standby, reporting to the master') : i18n.t('standby, not reporting')].filter(Boolean).join(' · '),
          to: { name: 'connectorsConnector', params: { id: connector.id } }
        }
        nodes.push(node)
        edges.push({
          key: `edge-standby-${node.key}`, from: head.key, to: node.key, color: colors.secondary, opacity: 0.6, dashed: true,
          // a bracket back to the master, inside the network trunk
          d: route(node.x + node.w, mid(node), head.x + head.w, mid(head) + 8, head.x + head.w + gap * 0.25)
        })
        return node
      })

      // networks of the connector, address order, each followed by its devices
      const { [connector.id]: { equipment, networks: equipmentNetworks } = {} } = props.equipment
      const devices = equipmentRows(equipment, equipmentNetworks || head.networks)
      const networks = sortNetworks(head.networks)
      const unrouted = devices.filter(device => !device.routed_via || !networks.includes(device.routed_via))
      const networkRows = [
        ...networks.map(network => ({ network, devices: devices.filter(device => device.routed_via === network) })),
        ...(unrouted.length ? [{ network: null, devices: unrouted }] : [])
      ]
      let networkRow = bandStart
      const serverNodes = {}
      networkRows.forEach(({ network, devices: networkDevices }) => {
        const via = (network) ? viaInterface(interfaceFor(network, hostInterfaces)) : null
        const node = {
          key: `network-${connector.id}-${network || 'other'}`, kind: 'network',
          x: netX, y: rowY(networkRow), w: boxW,
          fill: connected ? colors.white : colors.light, border: colors.gray, accent: network ? colors.teal : colors.secondary,
          icon: iconData(ICONS.network), iconColor: connected ? colors.dark : colors.secondary, mono: !!network,
          titleColor: connected ? colors.dark : colors.secondary, subtitleColor: colors.secondary,
          title: fit(network || i18n.t('other networks'), boxW - TEXT_X - 8),
          subtitle: fit([i18n.t('network · {count} device(s)', { count: networkDevices.length }), via].filter(Boolean).join(' · '), boxW - TEXT_X - 8, 'subtitle'),
          tooltip: network ? [network, connector.id, via].filter(Boolean).join(' · ') : i18n.t('Devices outside the connector networks'),
          to: { name: 'connectorsConnector', params: { id: connector.id }, query: { tab: 'devices' } }
        }
        nodes.push(node)
        edges.push({
          key: `edge-${head.key}-${node.key}`, from: head.key, to: node.key,
          color: connected ? colors.success : colors.secondary, opacity: connected ? 0.7 : 0.6, dashed: !connected,
          d: route(head.x + head.w, mid(head), node.x, mid(node), bandTrunk)
        })

        networkDevices.forEach((device, index) => {
          const endpoint = equipmentEndpoints(device, connected ? remote : null).join(', ')
          // the equipment lists a DNS server as ip:port, the topology keys it by connector too
          const server = (device.group === 'dns_connectors') ? dnsInfo.servers[`${connector.id}:${device.id}`] : null
          const tunnel = (server && connected) ? staticState(remote, { port: server.pfconnector_port, host: server.ip }) : null
          const deviceNode = {
            key: `device-${node.key}-${device.group}-${device.id}`, kind: 'device',
            x: devX, y: rowY(networkRow + index), w: boxW,
            fill: connected ? colors.white : colors.light, border: colors.gray,
            accent: connected ? (colors[deviceAccent[device.group]] || colors.secondary) : colors.secondary,
            icon: iconData(ICONS[device.group]), iconColor: connected ? colors.dark : colors.secondary,
            titleColor: connected ? colors.dark : colors.secondary, subtitleColor: colors.secondary,
            title: fit(device.id, boxW - TEXT_X - 8),
            titleExtra: fit((server) ? `${server.ip}:${server.port}` : ((device.description && device.description !== device.id) ? device.description : ''),
              Math.max(boxW - TEXT_X - 8 - ((device.id.length + 1) * CHAR_WIDTH.title), 0), 'subtitle'),
            dot: tunnelColor[tunnel],
            subtitle: fit([device.category, (server) ? i18n.t('{count} domain(s)', { count: server.chips.length }) : endpoint].filter(Boolean).join(' · '), boxW - TEXT_X - 8, 'subtitle'),
            tooltip: [device.category, device.id, device.description, device.type, endpoint, device.routed_via, tunnel && i18n.t('tunnel {state}', { state: tunnel.replace('_', ' ') })].filter(Boolean).join(' · '),
            to: device.routeName
              ? { name: device.routeName, params: { id: device.id } }
              : { name: 'connectorsConnector', params: { id: connector.id }, query: { tab: 'devices' } }
          }
          nodes.push(deviceNode)
          if (server)
            serverNodes[server.id] = deviceNode
          edges.push({
            key: `edge-${deviceNode.key}`, from: node.key, to: deviceNode.key,
            color: connected ? colors.success : colors.secondary, opacity: connected ? 0.7 : 0.6, dashed: !connected,
            d: route(node.x + node.w, mid(node), deviceNode.x, mid(deviceNode), node.x + node.w + gap / 2)
          })
        })
        networkRow += Math.max(networkDevices.length, 1)
      })

      networkRow += dnsBlock({
        key: connector.id, owner: connector.id, source: head, trunkX: bandTrunk, startRow: networkRow, serverNodes, remote, connected,
        edgeStyle: { color: connected ? colors.success : colors.secondary, opacity: connected ? 0.7 : 0.6, dashed: !connected }
      })

      row = Math.max(networkRow, bandStart + 1 + standby.length)
    })

    // DNS servers outside every connector network: PacketFence queries
    // them directly (local_connector), no tunnel
    if (dnsInfo.direct.length) {
      // without a known default route, an interface is only named when its subnet holds the server
      const directVia = server => (props.saas) ? null : (viaInterface(interfaceFor(server.ip, pfInterfaces)) || i18n.t('via the default route'))
      const directVias = [...new Set(dnsInfo.direct.map(directVia).filter(Boolean))]
        .sort((a, b) => (a === i18n.t('via the default route')) - (b === i18n.t('via the default route')))
      const direct = {
        key: 'direct', kind: 'direct',
        x: connX, y: rowY(row), w: boxW,
        fill: colors.white, border: colors.gray, accent: colors.secondary,
        icon: iconData(ICONS.packetfence), iconColor: colors.secondary,
        titleColor: colors.dark, subtitleColor: colors.secondary,
        title: fit(i18n.t('PacketFence (direct)'), boxW - TEXT_X - 8),
        subtitle: fit([i18n.t('no tunnel'), ...directVias].join(' · '), boxW - TEXT_X - 8, 'subtitle'),
        tooltip: i18n.t('DNS servers outside the connector networks, queried by PacketFence directly'),
        to: { name: 'connectorsConnectors' }
      }
      const outside = {
        key: 'direct-network', kind: 'network',
        x: netX, y: rowY(row), w: boxW,
        fill: colors.white, border: colors.gray, accent: colors.secondary,
        icon: iconData(ICONS.network), iconColor: colors.secondary,
        titleColor: colors.dark, subtitleColor: colors.secondary,
        title: fit(i18n.t('outside connector networks'), boxW - TEXT_X - 8),
        subtitle: fit(i18n.t('network · {count} device(s)', { count: dnsInfo.direct.length }), boxW - TEXT_X - 8, 'subtitle'),
        tooltip: i18n.t('DNS servers outside the connector networks, queried by PacketFence directly'),
        to: { name: 'connectorsConnectors' }
      }
      nodes.push(direct, outside)
      edges.push(
        { key: 'edge-pf-direct', from: packetfence.key, to: direct.key, color: colors.secondary, opacity: 0.6, d: route(packetfence.x + packetfence.w, mid(packetfence), direct.x, mid(direct), pfTrunk) },
        { key: 'edge-direct-network', from: direct.key, to: outside.key, color: colors.secondary, opacity: 0.6, d: route(direct.x + direct.w, mid(direct), outside.x, mid(outside), direct.x + direct.w + gap / 2) }
      )
      const serverNodes = {}
      dnsInfo.direct.forEach((server, index) => {
        const node = {
          key: `direct-dns-${server.id}`, kind: 'device',
          x: devX, y: rowY(row + index), w: boxW,
          fill: colors.white, border: colors.gray, accent: colors[deviceAccent.dns_connectors],
          icon: iconData(ICONS.dns_connectors), iconColor: colors.dark,
          titleColor: colors.dark, subtitleColor: colors.secondary,
          title: fit(server.id, boxW - TEXT_X - 8),
          titleExtra: fit(`${server.ip}:${server.port}`, Math.max(boxW - TEXT_X - 8 - ((server.id.length + 1) * CHAR_WIDTH.title), 0), 'subtitle'),
          subtitle: fit([i18n.t('DNS server'), i18n.t('{count} domain(s)', { count: server.chips.length })].join(' · '), boxW - TEXT_X - 8, 'subtitle'),
          tooltip: [i18n.t('DNS server'), server.id, `${server.ip}:${server.port}`, i18n.t('no tunnel'), directVia(server)].filter(Boolean).join(' · '),
          to: dnsSettings(server.connector)
        }
        nodes.push(node)
        serverNodes[server.id] = node
        edges.push({
          key: `edge-${node.key}`, from: outside.key, to: node.key, color: colors.secondary, opacity: 0.6,
          d: route(outside.x + outside.w, mid(outside), node.x, mid(node), outside.x + outside.w + gap / 2)
        })
      })
      const directRows = dnsInfo.direct.length + dnsBlock({
        key: 'direct', owner: null, source: direct, trunkX: direct.x + direct.w + gap / 2, startRow: row + dnsInfo.direct.length, serverNodes, remote: null, connected: false,
        edgeStyle: { color: colors.secondary, opacity: 0.6 }
      })
      row += directRows
    }

    return {
      width: W,
      height: rowY(Math.max(row, 1)) + PAD - (ROW_HEIGHT - NODE_HEIGHT),
      nodes,
      edges
    }
  })

  // hovered box: its path up to PacketFence, everything below it, and the
  // DNS servers / domains it is bracketed to (with their own path up)
  const related = computed(() => {
    const key = hovered.value
    if (!key)
      return null
    const { edges } = layout.value
    const links = edges.filter(edge => edge.from && !edge.bracket)
    const relatedNodes = new Set([key])
    const relatedEdges = new Set()
    const walk = (start, next) => {
      const queue = [start]
      while (queue.length) {
        const current = queue.shift()
        next(current).forEach(edge => {
          relatedEdges.add(edge.key)
          const other = (edge.from === current) ? edge.to : edge.from
          if (!relatedNodes.has(other)) {
            relatedNodes.add(other)
            queue.push(other)
          }
        })
      }
    }
    const up = start => walk(start, current => links.filter(edge => edge.to === current))
    up(key)
    walk(key, current => links.filter(edge => edge.from === current))
    edges.filter(edge => edge.bracket && (edge.from === key || edge.to === key)).forEach(edge => {
      relatedEdges.add(edge.key)
      const other = (edge.from === key) ? edge.to : edge.from
      relatedNodes.add(other)
      up(other)
    })
    return { nodes: relatedNodes, edges: relatedEdges }
  })

  // actions menu of a connector: each item opens the connector view on the
  // matching tab; terminal and restart are confirmed there (TOTP / typed)
  const menu = ref(null)
  const menuRef = ref(null)
  const menuIcon = iconData('ellipsis-v')
  const canUpdate = computed(() => acl.$can('update', 'connectors'))
  const openMenu = node => {
    if (menu.value && menu.value.key === node.key) {
      menu.value = null
      return
    }
    const connected = node.status === 'up'
    const notConnected = i18n.t('The tunnel is not connected.')
    const at = (tab, action) => ({ name: 'connectorsConnector', params: { id: node.id }, query: { tab, ...(action ? { action } : {}) } })
    const items = [
      { key: 'open', icon: 'external-link-alt', label: i18n.t('Open connector'), to: at('overview') },
      ...(canUpdate.value ? [{ key: 'terminal', icon: 'terminal', label: i18n.t('Open remote terminal...'), to: at('troubleshooting', 'terminal'), disabled: !connected, reason: notConnected }] : []),
      { key: 'logs', icon: 'scroll', label: i18n.t('View logs'), to: at('troubleshooting'), disabled: !connected, reason: notConnected },
      { key: 'dns', icon: 'stethoscope', label: i18n.t('DNS lookup'), to: at('networking', 'dns') },
      ...(canUpdate.value ? [{ key: 'restart', icon: 'redo', label: i18n.t('Restart connector...'), to: at('troubleshooting', 'restart'), disabled: !connected, reason: notConnected, danger: true }] : []),
      ...((node.dnsDomains || []).length ? [{ key: 'dns-header', header: i18n.t('DNS domains') }] : []),
      ...(node.dnsDomains || []).map(issue => ({
        key: `dns-${issue.domain}`,
        icon: (issue.state === 'ok') ? 'check' : 'exclamation-triangle',
        label: issue.domain,
        detail: issue.label,
        warning: issue.state !== 'ok',
        to: issue.to
      }))
    ]
    menu.value = {
      key: node.key,
      id: node.id,
      name: node.name || node.id,
      left: Math.max(0, node.x + node.w - 220),
      top: node.y + NODE_HEIGHT + 2,
      items
    }
  }
  const closeMenu = () => { menu.value = null }
  const onDocumentClick = event => {
    if (menu.value && menuRef.value && !menuRef.value.contains(event.target))
      closeMenu()
  }
  const onDocumentKeydown = event => {
    if (event.key === 'Escape')
      closeMenu()
  }
  onMounted(() => {
    document.addEventListener('click', onDocumentClick)
    document.addEventListener('keydown', onDocumentKeydown)
  })
  onBeforeUnmount(() => {
    document.removeEventListener('click', onDocumentClick)
    document.removeEventListener('keydown', onDocumentKeydown)
  })
  const onMenuItem = item => {
    closeMenu()
    goTo(item.to)
  }

  const goTo = to => {
    if (to)
      $router.push(to).catch(e => { if (e.name !== 'NavigationDuplicated') throw e })
  }

  return {
    wrapperRef,
    menu,
    menuRef,
    menuIcon,
    openMenu,
    onMenuItem,
    layout,
    colors,
    hovered,
    related,
    FADED,
    nodeHeight: NODE_HEIGHT,
    iconSize: ICON_SIZE,
    textX: TEXT_X,
    monoFont: MONO_FONT,
    goTo
  }
}

// @vue/component
export default {
  name: 'the-topology',
  components,
  props,
  setup
}
</script>
