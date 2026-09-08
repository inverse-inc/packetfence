<template>
  <b-card no-body>
    <b-card-header class="d-flex align-items-center">
      <h4 class="mb-0 flex-grow-1">{{ $t('Connectors Topology') }}</h4>
      <small class="text-muted mr-3" v-if="updatedAt">{{ $t('Updated') }} {{ updatedAt }}</small>
      <b-button size="sm" variant="outline-secondary" class="mr-1" @click="paused = !paused">
        <icon :name="paused ? 'play' : 'pause'" class="mr-1" />{{ paused ? $t('Resume') : $t('Pause') }}
      </b-button>
      <b-button size="sm" variant="outline-primary" @click="goToCollection">{{ $t('Connectors list') }}</b-button>
    </b-card-header>
    <div class="card-body">
      <b-alert :show="!!error" variant="danger" class="mb-3">{{ error }}</b-alert>
      <b-alert :show="!error && loaded && !nodes.length" variant="info" class="mb-0">{{ $t('No connector is configured.') }}</b-alert>
      <div v-if="nodes.length" class="connectors-topology">
        <svg :viewBox="`0 0 ${width} ${height}`" class="w-100" preserveAspectRatio="xMidYMin meet" :style="{ maxHeight: `${height}px` }">
          <defs>
            <filter id="topology-shadow" x="-10%" y="-10%" width="120%" height="140%">
              <feDropShadow dx="0" dy="1" stdDeviation="1.5" flood-opacity="0.15" />
            </filter>
          </defs>

          <!-- links -->
          <g v-for="node in nodes" :key="`link-${node.id}`" class="link" @click="select(node.id)">
            <path :d="node.path" fill="none" stroke="#e9ecef" :stroke-width="node.strokeWidth + 4" stroke-linecap="round" />
            <path :d="node.path" fill="none" :stroke="node.color" :stroke-width="node.strokeWidth" stroke-linecap="round"
              :stroke-dasharray="node.dash" :class="{ flowing: node.flowing }" :style="node.flowing ? { animationDuration: node.flowDuration } : {}">
              <title>{{ node.title }}</title>
            </path>
            <g v-if="node.connected" :transform="`translate(${node.labelX}, ${node.labelY})`" class="link-label">
              <text text-anchor="middle" dy="-4">{{ node.rttLabel }}</text>
              <text text-anchor="middle" dy="12" class="text-rate">{{ node.rateLabel }}</text>
            </g>
          </g>

          <!-- PacketFence -->
          <g :transform="`translate(${pf.x}, ${pf.y})`" filter="url(#topology-shadow)">
            <rect :width="pf.w" :height="pf.h" rx="10" fill="#0d6efd" />
            <text :x="pf.w / 2" :y="pf.h / 2 - 4" text-anchor="middle" fill="#fff" class="node-title">PacketFence</text>
            <text :x="pf.w / 2" :y="pf.h / 2 + 14" text-anchor="middle" fill="#dbe7ff" class="node-sub">{{ $t('{n} connector(s), {c} connected', { n: nodes.length, c: connectedCount }) }}</text>
          </g>

          <!-- connectors -->
          <g v-for="node in nodes" :key="`node-${node.id}`">
            <g :transform="`translate(${node.x}, ${node.y})`" class="connector-node" :class="{ selected: node.id === selectedId }"
              filter="url(#topology-shadow)" @click="select(node.id)">
              <title>{{ node.title }}</title>
              <rect :width="node.w" :height="node.h" rx="8" fill="#fff" :stroke="node.color" :stroke-width="node.id === selectedId ? 3 : 2" />
              <circle :cx="14" :cy="node.h / 2" r="5" :fill="node.color" />
              <text :x="28" :y="node.h / 2 - 5" class="node-title">{{ node.label }}</text>
              <text v-if="node.haVip" :x="node.w - 10" :y="node.h / 2 - 5" text-anchor="end" class="node-sub" fill="#6c757d">HA {{ node.haVip }}</text>
              <text :x="28" :y="node.h / 2 + 12" class="node-sub" fill="#6c757d">{{ node.subLabel }}</text>
            </g>
            <!-- HA standby satellites -->
            <g v-for="sat in node.satellites" :key="`sat-${node.id}-${sat.address}`">
              <line :x1="node.x + node.w" :y1="node.y + node.h / 2" :x2="sat.x" :y2="sat.y + sat.h / 2" :stroke="sat.color" stroke-width="1.5" stroke-dasharray="3 3" />
              <g :transform="`translate(${sat.x}, ${sat.y})`" class="satellite">
                <title>{{ sat.title }}</title>
                <rect :width="sat.w" :height="sat.h" rx="10" fill="#fff" :stroke="sat.color" stroke-width="1.5" />
                <circle :cx="10" :cy="sat.h / 2" r="3.5" :fill="sat.color" />
                <text :x="19" :y="sat.h / 2 + 3.5" class="sat-label">{{ sat.label }}</text>
              </g>
            </g>
          </g>
        </svg>
        <div class="d-flex flex-wrap align-items-center mt-2 small text-muted">
          <span class="mr-3"><span class="legend-swatch" style="background:#28a745"></span>{{ $t('connected') }}</span>
          <span class="mr-3"><span class="legend-swatch" style="background:#dc3545"></span>{{ $t('tunnel down') }}</span>
          <span class="mr-3"><span class="legend-swatch" style="background:#adb5bd"></span>{{ $t('never connected') }}</span>
          <span class="mr-3"><span class="legend-swatch" style="background:#fd7e14"></span>{{ $t('standby host with FreeRADIUS down') }}</span>
          <span>{{ $t('Link width and animation follow the tunnel throughput; the label shows the keepalive round trip and the rate from / to the site. Click a connector for the details. Refreshed every {s} seconds.', { s: pollSeconds }) }}</span>
        </div>

        <!-- traffic history -->
        <b-row class="mt-3">
          <b-col lg="8" class="mb-3 mb-lg-0">
            <b-card no-body class="h-100">
              <b-card-header class="d-flex align-items-center py-2">
                <strong class="flex-grow-1">{{ $t('Tunnel traffic') }} <small class="text-muted">{{ selected ? selected.label : $t('all connectors') }}</small></strong>
                <b-button-group size="sm">
                  <b-button v-for="w in trafficWindows" :key="w.seconds" :variant="w.seconds === trafficWindow ? 'primary' : 'outline-secondary'" @click="trafficWindow = w.seconds">{{ w.label }}</b-button>
                </b-button-group>
              </b-card-header>
              <div class="card-body p-2">
                <div v-show="hasTraffic" ref="trafficRef" class="topology-chart"></div>
                <p v-show="!hasTraffic" class="text-muted small text-center my-4">{{ $t('Collecting the history: the servers sample the tunnels every few seconds, the chart appears with the first samples.') }}</p>
              </div>
            </b-card>
          </b-col>
          <b-col lg="4">
            <b-card no-body class="h-100">
              <b-card-header class="py-2"><strong>{{ $t('Top services') }} <small class="text-muted">{{ $t('over the window') }}</small></strong></b-card-header>
              <div class="card-body p-2">
                <div v-show="hasTraffic" ref="servicesRef" class="topology-chart"></div>
                <p v-show="!hasTraffic" class="text-muted small text-center my-4">{{ $t('No traffic recorded yet.') }}</p>
              </div>
            </b-card>
          </b-col>
        </b-row>

        <!-- details of the selected connector -->
        <b-card v-if="selected" class="mt-3" no-body>
          <b-card-header class="d-flex align-items-center py-2">
            <strong class="flex-grow-1">{{ selected.label }} <small class="text-muted text-monospace">{{ selected.id }}</small></strong>
            <b-button size="sm" variant="outline-primary" class="mr-1" @click="goToItem({ id: selected.id })">{{ $t('Open connector') }}</b-button>
            <b-button size="sm" variant="outline-secondary" @click="selectedId = null">{{ $t('Close') }}</b-button>
          </b-card-header>
          <b-row no-gutters>
            <b-col :md="selected.haRows.length ? 7 : 12" class="p-3">
              <h6 class="text-secondary">{{ $t('Traffic by service') }}</h6>
              <b-table-simple v-if="selected.services.length" small class="mb-0">
                <b-thead>
                  <b-tr>
                    <b-th>{{ $t('Service') }}</b-th>
                    <b-th>{{ $t('Destination') }}</b-th>
                    <b-th class="text-right">{{ $t('From site') }}</b-th>
                    <b-th class="text-right">{{ $t('To site') }}</b-th>
                    <b-th class="text-right">{{ $t('Active') }}</b-th>
                    <b-th class="text-right">{{ $t('Total') }}</b-th>
                  </b-tr>
                </b-thead>
                <b-tbody>
                  <b-tr v-for="svc in selected.services" :key="svc.key">
                    <b-td>{{ svc.name }}<b-badge v-if="svc.reverse" variant="light" class="border ml-1" :title="$t('Opened by PacketFence toward the connector')">{{ $t('reverse') }}</b-badge></b-td>
                    <b-td class="text-monospace small">{{ svc.destination }}</b-td>
                    <b-td class="text-right text-monospace">{{ svc.rateIn }}</b-td>
                    <b-td class="text-right text-monospace">{{ svc.rateOut }}</b-td>
                    <b-td class="text-right">{{ svc.active }}</b-td>
                    <b-td class="text-right text-monospace small">↓ {{ svc.totalIn }} ↑ {{ svc.totalOut }}</b-td>
                  </b-tr>
                </b-tbody>
              </b-table-simple>
              <p v-else class="text-muted mb-0">{{ $t('No traffic carried by the tunnel yet.') }}</p>
            </b-col>
            <b-col v-if="selected.haRows.length" md="5" class="p-3 border-left">
              <h6 class="text-secondary">{{ $t('High availability') }} <small class="text-muted">VIP {{ selected.haVip }}</small></h6>
              <b-table-simple small class="mb-0">
                <b-thead>
                  <b-tr>
                    <b-th>{{ $t('Host') }}</b-th>
                    <b-th>{{ $t('Role') }}</b-th>
                    <b-th>{{ $t('FreeRADIUS') }}</b-th>
                    <b-th>{{ $t('State') }}</b-th>
                  </b-tr>
                </b-thead>
                <b-tbody>
                  <b-tr v-for="row in selected.haRows" :key="row.address">
                    <b-td class="text-monospace">{{ row.hostname }} <small class="text-muted">{{ row.address }}</small></b-td>
                    <b-td>{{ row.role }}</b-td>
                    <b-td><b-badge :variant="row.radiusOk ? 'success' : 'warning'">{{ row.radiusOk ? $t('ok') : $t('down') }}</b-badge></b-td>
                    <b-td><b-badge :variant="row.alive ? 'success' : 'danger'">{{ row.alive ? $t('alive') : $t('not reporting') }}</b-badge></b-td>
                  </b-tr>
                </b-tbody>
              </b-table-simple>
            </b-col>
          </b-row>
        </b-card>
      </div>
    </div>
  </b-card>
</template>
<script>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import bytes from '@/utils/bytes'
import plotly, { config as plotlyConfig } from '@/utils/plotly'
import api from '../_api'
import { useRouter } from '../_composables/useCollection'

const pollSeconds = 3
// The history is refreshed less often than the live map: the servers sample
// every 5 s, so 15 s adds a few points per refresh.
const trafficPollSeconds = 15
const trafficWindows = [
  { seconds: 300, label: '5 min' },
  { seconds: 900, label: '15 min' },
  { seconds: 3600, label: '1 h' }
]

// Layout constants (SVG user units; the viewBox scales to the card width).
const WIDTH = 1000
const PF = { x: 40, w: 180, h: 64 }
const NODE = { x: 560, w: 240, minH: 56, gap: 18, top: 36 }
const SAT = { x: NODE.x + NODE.w + 26, w: 170, h: 20, gap: 6 }

// Human name of a tunnel destination, from the port PacketFence exposes.
const SERVICE_NAMES = {
  '1812/udp': 'RADIUS authentication',
  '1813/udp': 'RADIUS accounting',
  '1815/udp': 'RADIUS CLI',
  '80/tcp': 'Captive portal (HTTP)',
  '443/tcp': 'Captive portal (HTTPS)',
  '8880/tcp': 'Captive portal (HTTP)',
  '8843/tcp': 'Captive portal (HTTPS)',
  '3306/tcp': 'MySQL',
  '6379/tcp': 'Redis',
  '9090/tcp': 'Web services',
  '22226/tcp': 'Connector API',
  '4723/tcp': 'Fingerbank collector'
}
const serviceName = (destination, reverse) => {
  const m = destination.match(/^(.*?):(\d+)(?:\/(\w+))?(?:\|(\w+))?$/)
  if (!m)
    return destination
  const [ , host, port, proto = 'tcp' ] = m
  if (/fingerbank\.org$/.test(host))
    return 'Fingerbank API'
  const named = SERVICE_NAMES[`${port}/${proto}`]
  if (named)
    return named
  const p = parseInt(port)
  if (p >= 30000 && p <= 30999)
    return i18n.t('DNS / RADIUS source tunnel')
  if (p >= 23000 && p <= 23999)
    return reverse ? 'Fingerbank collector' : i18n.t('NTLM authentication')
  return `${proto.toUpperCase()} ${port}`
}

const setup = (props, context) => {
  const { root: { $router } = {} } = context
  const { goToCollection, goToItem } = useRouter($router)

  const connectors = ref([])
  const loaded = ref(false)
  const error = ref(null)
  const paused = ref(false)
  const updatedAt = ref(null)
  const selectedId = ref(null)
  // Previous cumulative counters per connector (and per service), to derive
  // bytes per second between two samples.
  const previous = new Map()
  const rates = ref({})
  const serviceRates = ref({})

  const rate = (now, prev, dt, field) => (now[field] >= prev[field]) ? (now[field] - prev[field]) / dt : 0

  const refresh = () => {
    return api.topology().then(reply => {
      const list = reply.connectors || []
      const nextRates = {}
      const nextServiceRates = {}
      list.forEach(c => {
        const stats = c.stats || null
        const prev = previous.get(c.id)
        if (stats && prev && stats.sampled_at && prev.sampled_at) {
          const dt = (new Date(stats.sampled_at) - new Date(prev.sampled_at)) / 1000
          if (dt > 0) {
            nextRates[c.id] = { in: rate(stats, prev, dt, 'bytes_in'), out: rate(stats, prev, dt, 'bytes_out') }
            const prevServices = new Map((prev.services || []).map(s => [`${s.reverse ? '<' : ''}${s.destination}`, s]))
            nextServiceRates[c.id] = {}
            ;(stats.services || []).forEach(s => {
              const key = `${s.reverse ? '<' : ''}${s.destination}`
              const p = prevServices.get(key)
              if (p)
                nextServiceRates[c.id][key] = { in: rate(s, p, dt, 'bytes_in'), out: rate(s, p, dt, 'bytes_out') }
            })
          }
        }
        if (stats)
          previous.set(c.id, stats)
        else
          previous.delete(c.id)
      })
      rates.value = nextRates
      serviceRates.value = nextServiceRates
      connectors.value = list
      error.value = null
      updatedAt.value = new Date().toLocaleTimeString()
    }).catch(() => {
      error.value = i18n.t('Unable to load the connectors topology.')
    }).finally(() => {
      loaded.value = true
    })
  }

  let interval = null
  const start = () => {
    if (interval) clearInterval(interval)
    interval = setInterval(() => { if (!paused.value) refresh() }, pollSeconds * 1000)
  }
  onMounted(() => { refresh(); start() })
  onBeforeUnmount(() => { if (interval) clearInterval(interval) })
  watch(paused, value => { if (!value) refresh() })

  const select = id => { selectedId.value = (selectedId.value === id) ? null : id }

  // Traffic history (rates recorded by the pfconnector servers).
  const trafficWindow = ref(900)
  const traffic = ref({}) // connector id -> series {t, in, out, services}
  const trafficRef = ref(null)
  const servicesRef = ref(null)
  const hasTraffic = computed(() => Object.values(traffic.value).some(s => s && s.t && s.t.length))

  const refreshTraffic = () => {
    return api.traffic(trafficWindow.value).then(reply => {
      traffic.value = reply.connectors || {}
    }).catch(() => {
      traffic.value = {}
    }).then(() => nextTick(renderCharts))
  }

  // Series to chart: the selected connector's, or all connectors summed per
  // 5 s bucket (the pods sample at slightly different instants).
  const chartedSeries = () => {
    const all = traffic.value
    if (selectedId.value && all[selectedId.value])
      return all[selectedId.value]
    const buckets = new Map()
    const services = {}
    Object.values(all).forEach(s => {
      if (!s || !s.t) return
      const step = s.interval_s || 5
      s.t.forEach((t, i) => {
        const b = Math.floor(t / step) * step
        const cur = buckets.get(b) || { in: 0, out: 0 }
        cur.in += s.in[i] || 0
        cur.out += s.out[i] || 0
        buckets.set(b, cur)
      })
      Object.entries(s.services || {}).forEach(([dest, ss]) => {
        const key = `${ss.reverse ? '<' : ''}${dest}`
        const acc = services[key] || (services[key] = { reverse: !!ss.reverse, bytes: 0 })
        ss.in.forEach((v, i) => { acc.bytes += ((v || 0) + (ss.out[i] || 0)) * step })
      })
    })
    const t = [...buckets.keys()].sort((a, b) => a - b)
    return { t, in: t.map(b => buckets.get(b).in), out: t.map(b => buckets.get(b).out), interval_s: 5, aggregatedServices: services }
  }

  const servicesTotals = series => {
    if (series.aggregatedServices)
      return Object.entries(series.aggregatedServices).map(([key, v]) => ({ dest: key.replace(/^</, ''), reverse: v.reverse, bytes: v.bytes }))
    const step = series.interval_s || 5
    return Object.entries(series.services || {}).map(([dest, ss]) => ({
      dest, reverse: !!ss.reverse,
      bytes: ss.in.reduce((sum, v, i) => sum + ((v || 0) + (ss.out[i] || 0)) * step, 0)
    }))
  }

  const chartLayout = {
    margin: { l: 60, r: 10, t: 10, b: 40 },
    height: 260,
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    legend: { orientation: 'h', y: 1.12 },
    hovermode: 'x unified'
  }

  const renderCharts = () => {
    if (!hasTraffic.value || !trafficRef.value || !servicesRef.value)
      return
    const series = chartedSeries()
    const x = series.t.map(t => new Date(t * 1000))
    const { locale } = i18n
    plotly.react(trafficRef.value, [
      { x, y: series.in, name: i18n.t('From site'), type: 'scatter', mode: 'lines', fill: 'tozeroy', line: { color: '#0d6efd', width: 1.5 }, hovertemplate: '%{y:.3~s}B/s' },
      { x, y: series.out, name: i18n.t('To site'), type: 'scatter', mode: 'lines', fill: 'tozeroy', line: { color: '#28a745', width: 1.5 }, hovertemplate: '%{y:.3~s}B/s' }
    ], {
      ...chartLayout,
      xaxis: { type: 'date', tickformat: '%H:%M' },
      yaxis: { rangemode: 'tozero', tickformat: '~s', ticksuffix: 'B/s', fixedrange: true }
    }, { ...plotlyConfig, displayModeBar: false, scrollZoom: false, locale })

    const top = servicesTotals(series).filter(s => s.bytes > 0).sort((a, b) => a.bytes - b.bytes).slice(-10)
    plotly.react(servicesRef.value, [{
      type: 'bar', orientation: 'h',
      x: top.map(s => s.bytes),
      y: top.map(s => `${serviceName(s.dest, s.reverse)}${s.reverse ? ' ⟵' : ''}`),
      text: top.map(s => `${bytes.toHuman(s.bytes, 1, true)}B`),
      textposition: 'auto',
      hovertext: top.map(s => s.dest),
      hoverinfo: 'text+x',
      marker: { color: '#6c757d' }
    }], {
      ...chartLayout,
      margin: { l: 170, r: 10, t: 10, b: 40 },
      showlegend: false,
      xaxis: { tickformat: '~s', ticksuffix: 'B', fixedrange: true },
      yaxis: { automargin: true, fixedrange: true }
    }, { ...plotlyConfig, displayModeBar: false, scrollZoom: false, locale })
  }

  let trafficInterval = null
  onMounted(() => {
    refreshTraffic()
    trafficInterval = setInterval(() => { if (!paused.value) refreshTraffic() }, trafficPollSeconds * 1000)
  })
  onBeforeUnmount(() => {
    if (trafficInterval) clearInterval(trafficInterval)
    if (trafficRef.value) plotly.purge(trafficRef.value)
    if (servicesRef.value) plotly.purge(servicesRef.value)
  })
  watch(trafficWindow, () => refreshTraffic())
  watch(selectedId, () => nextTick(renderCharts))

  const connectedCount = computed(() => connectors.value.filter(c => c.connected).length)

  const rateLabel = r => `${bytes.toHuman(r, 1, true)}B/s`
  const totalLabel = b => `${bytes.toHuman(b, 1, true)}B`
  const truncate = (text, n) => (text && text.length > n) ? `${text.slice(0, n - 1)}…` : (text || '')
  // Characters that fit in `px` for the text styles (approximate glyph
  // widths of the 14px bold title, the 11px sub label and the 10px satellite).
  const fitTitle = px => Math.floor(px / 8)
  const fitSub = px => Math.floor(px / 6.2)
  const fitSat = px => Math.floor(px / 5.6)
  // Addresses shown in the box: IPv4 first, link-local IPv6 left to the
  // tooltip; the full list stays in the title.
  const displayAddresses = ips => {
    const v4 = ips.filter(ip => ip.indexOf(':') === -1)
    const v6 = ips.filter(ip => ip.indexOf(':') !== -1 && !/^fe[89ab]/i.test(ip))
    return [...v4, ...v6]
  }

  // Standby hosts of an HA connector, from the active host's "ha" block.
  const standbysOf = c => ((c.ha && c.ha.peers) || []).filter(p => p.address)

  const nodes = computed(() => {
    const cy = heightFor(connectors.value) / 2
    let y = NODE.top
    return connectors.value.map(c => {
      const standbys = standbysOf(c)
      const h = Math.max(NODE.minH, 12 + standbys.length * (SAT.h + SAT.gap))
      const nodeY = y
      y += h + NODE.gap
      const my = nodeY + h / 2
      const r = rates.value[c.id] || null
      const total = r ? r.in + r.out : 0
      // Width and animation speed grow with the log of the throughput:
      // 1 kB/s is barely visible, 1 MB/s is a thick fast link.
      const magnitude = Math.log10(1 + total / 1000)
      const color = c.connected ? '#28a745' : (c.stats ? '#dc3545' : '#adb5bd')
      const flowing = c.connected && total > 0
      const stats = c.stats || {}
      const ips = (c.remote_ips || []).join(', ')
      const shownIps = displayAddresses(c.remote_ips || []).join(', ')
      const rtt = c.connected && stats.rtt_ms ? `${Math.round(stats.rtt_ms * 10) / 10} ms` : ''
      const haVip = c.ha_vip ? c.ha_vip.split('/')[0] : ''
      // Text area: box width minus the left padding (28) and right margin
      // (10); the title shares its line with the HA label when there is one.
      const textWidth = NODE.w - 38
      const titleWidth = haVip ? textWidth - (haVip.length + 3) * 6.2 - 8 : textWidth
      const satellites = standbys.map((p, i) => {
        const satColor = !p.alive ? '#dc3545' : (p.radius_ok === false ? '#fd7e14' : '#28a745')
        return {
          address: p.address,
          x: SAT.x,
          y: nodeY + 6 + i * (SAT.h + SAT.gap),
          w: SAT.w, h: SAT.h,
          color: satColor,
          label: truncate(`${p.hostname || p.address} ${p.hostname ? p.address : ''}`.trim(), fitSat(SAT.w - 24)),
          title: [
            `${i18n.t('Standby host')} ${p.hostname || ''} ${p.address}`,
            p.alive ? i18n.t('reporting') : i18n.t('not reporting'),
            p.radius_ok === false ? i18n.t('FreeRADIUS down') : i18n.t('FreeRADIUS ok'),
            p.version ? `${i18n.t('Version')} ${p.version}` : null
          ].filter(Boolean).join('\n')
        }
      })
      return {
        id: c.id,
        connected: c.connected,
        haVip,
        x: NODE.x, y: nodeY, w: NODE.w, h,
        label: truncate(c.description || c.id, fitTitle(titleWidth)),
        subLabel: truncate(c.connected ? (shownIps || i18n.t('connected')) : (c.stats ? i18n.t('tunnel down') : i18n.t('never connected')), fitSub(textWidth)),
        color,
        path: `M ${PF.x + PF.w} ${cy} C ${PF.x + PF.w + 170} ${cy}, ${NODE.x - 170} ${my}, ${NODE.x} ${my}`,
        strokeWidth: c.connected ? 2 + Math.min(12, magnitude * 3) : 1.5,
        dash: c.connected ? (flowing ? '10 8' : null) : '4 6',
        flowing,
        flowDuration: `${Math.max(0.25, 2.5 / (1 + magnitude))}s`,
        labelX: (PF.x + PF.w + NODE.x) / 2,
        labelY: (cy + my) / 2,
        rttLabel: rtt || i18n.t('no keepalive yet'),
        rateLabel: r ? `↓ ${rateLabel(r.in)}  ↑ ${rateLabel(r.out)}` : '…',
        satellites,
        title: [
          c.id,
          c.description,
          ips ? `${i18n.t('Addresses')}: ${ips}` : null,
          stats.connected_at ? `${i18n.t('Connected since')} ${new Date(stats.connected_at).toLocaleString()}` : null,
          stats.channels !== undefined ? `${i18n.t('Open channels')}: ${stats.channels}` : null,
          stats.bytes_in !== undefined ? `${i18n.t('Total')}: ↓ ${totalLabel(stats.bytes_in)} ↑ ${totalLabel(stats.bytes_out)}` : null
        ].filter(Boolean).join('\n')
      }
    })
  })

  // Height of the whole drawing for a list of connectors (node heights vary
  // with their number of standby hosts).
  const heightFor = list => {
    const total = list.reduce((sum, c) => sum + Math.max(NODE.minH, 12 + standbysOf(c).length * (SAT.h + SAT.gap)) + NODE.gap, 0)
    return Math.max(300, NODE.top * 2 + total)
  }
  const height = computed(() => heightFor(connectors.value))
  const pf = computed(() => ({ ...PF, y: height.value / 2 - PF.h / 2 }))

  // Details panel of the selected connector.
  const selected = computed(() => {
    const c = connectors.value.find(c => c.id === selectedId.value)
    if (!c)
      return null
    const node = nodes.value.find(n => n.id === c.id) || {}
    const svcRates = serviceRates.value[c.id] || {}
    const services = ((c.stats && c.stats.services) || []).map(s => {
      const key = `${s.reverse ? '<' : ''}${s.destination}`
      const r = svcRates[key]
      return {
        key,
        name: serviceName(s.destination, s.reverse),
        destination: s.destination,
        reverse: !!s.reverse,
        rateIn: r ? rateLabel(r.in) : '…',
        rateOut: r ? rateLabel(r.out) : '…',
        active: s.active,
        totalIn: totalLabel(s.bytes_in),
        totalOut: totalLabel(s.bytes_out),
        total: s.bytes_in + s.bytes_out
      }
    }).sort((a, b) => b.total - a.total)
    const ha = c.ha || null
    const haRows = ha ? [
      { hostname: ha.hostname, address: ha.address, role: i18n.t('active'), radiusOk: ha.radius_ok !== false, alive: true },
      ...standbysOf(c).map(p => ({ hostname: p.hostname, address: p.address, role: i18n.t('standby'), radiusOk: p.radius_ok !== false, alive: !!p.alive }))
    ] : []
    return { id: c.id, label: c.description || c.id, haVip: node.haVip, services, haRows }
  })

  return {
    pollSeconds,
    width: WIDTH,
    height,
    pf,
    nodes,
    connectedCount,
    loaded,
    error,
    paused,
    updatedAt,
    selectedId,
    selected,
    select,
    trafficWindows,
    trafficWindow,
    trafficRef,
    servicesRef,
    hasTraffic,
    goToCollection,
    goToItem
  }
}

// @vue/component
export default {
  name: 'the-topology',
  inheritAttrs: false,
  setup
}
</script>
<style lang="scss">
.connectors-topology {
  svg {
    font-family: inherit;
    .node-title { font-size: 14px; font-weight: 600; fill: #212529; }
    .node-sub { font-size: 11px; }
    .sat-label { font-size: 10px; fill: #495057; }
    .connector-node, .link { cursor: pointer; }
    .connector-node:hover rect { fill: #f8f9fa; }
    .connector-node.selected rect { fill: #f1f8ff; }
    .link-label text { font-size: 11px; fill: #495057; paint-order: stroke; stroke: #fff; stroke-width: 3px; }
    .link-label .text-rate { fill: #6c757d; }
    path.flowing { animation: topology-flow 1s linear infinite; }
  }
  .legend-swatch { display: inline-block; width: 12px; height: 12px; border-radius: 2px; margin-right: 4px; vertical-align: middle; }
  .topology-chart { width: 100%; min-height: 260px; }
}
@keyframes topology-flow {
  from { stroke-dashoffset: 36; }
  to { stroke-dashoffset: 0; }
}
</style>
