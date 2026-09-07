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
          <g v-for="node in nodes" :key="`link-${node.id}`">
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
          <g v-for="node in nodes" :key="`node-${node.id}`" :transform="`translate(${node.x}, ${node.y})`"
            class="connector-node" filter="url(#topology-shadow)" @click="goToItem({ id: node.id })">
            <title>{{ node.title }}</title>
            <rect :width="node.w" :height="node.h" rx="8" fill="#fff" :stroke="node.color" stroke-width="2" />
            <circle :cx="14" :cy="node.h / 2" r="5" :fill="node.color" />
            <text :x="28" :y="node.h / 2 - 5" class="node-title">{{ node.label }}</text>
            <text :x="28" :y="node.h / 2 + 12" class="node-sub" fill="#6c757d">{{ node.subLabel }}</text>
            <text v-if="node.haVip" :x="node.w - 10" :y="node.h / 2 + 12" text-anchor="end" class="node-sub" fill="#6c757d">HA {{ node.haVip }}</text>
          </g>
        </svg>
        <div class="d-flex flex-wrap align-items-center mt-2 small text-muted">
          <span class="mr-3"><span class="legend-swatch" style="background:#28a745"></span>{{ $t('connected') }}</span>
          <span class="mr-3"><span class="legend-swatch" style="background:#dc3545"></span>{{ $t('tunnel down') }}</span>
          <span class="mr-3"><span class="legend-swatch" style="background:#adb5bd"></span>{{ $t('never connected') }}</span>
          <span>{{ $t('Link width and animation follow the tunnel throughput; the label shows the keepalive round trip and the rate from / to the site. Refreshed every {s} seconds.', { s: pollSeconds }) }}</span>
        </div>
      </div>
    </div>
  </b-card>
</template>
<script>
import { computed, onBeforeUnmount, onMounted, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import bytes from '@/utils/bytes'
import api from '../_api'
import { useRouter } from '../_composables/useCollection'

const pollSeconds = 3

// Layout constants (SVG user units; the viewBox scales to the card width).
const WIDTH = 1000
const PF = { x: 60, w: 190, h: 64 }
const NODE = { x: 700, w: 260, h: 56, gap: 20, top: 40 }

const setup = (props, context) => {
  const { root: { $router } = {} } = context
  const { goToCollection, goToItem } = useRouter($router)

  const connectors = ref([])
  const loaded = ref(false)
  const error = ref(null)
  const paused = ref(false)
  const updatedAt = ref(null)
  // Previous cumulative counters per connector, to derive bytes per second.
  const previous = new Map()
  const rates = ref({})

  const refresh = () => {
    return api.topology().then(reply => {
      const list = reply.connectors || []
      const nextRates = {}
      list.forEach(c => {
        const stats = c.stats || null
        const prev = previous.get(c.id)
        if (stats && prev && stats.sampled_at && prev.sampled_at) {
          const dt = (new Date(stats.sampled_at) - new Date(prev.sampled_at)) / 1000
          if (dt > 0 && stats.bytes_in >= prev.bytes_in && stats.bytes_out >= prev.bytes_out) {
            nextRates[c.id] = {
              in: (stats.bytes_in - prev.bytes_in) / dt,
              out: (stats.bytes_out - prev.bytes_out) / dt
            }
          }
        }
        if (stats)
          previous.set(c.id, stats)
        else
          previous.delete(c.id)
      })
      rates.value = nextRates
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

  const height = computed(() => Math.max(300, NODE.top * 2 + connectors.value.length * (NODE.h + NODE.gap)))
  const pf = computed(() => ({ ...PF, y: height.value / 2 - PF.h / 2 }))
  const connectedCount = computed(() => connectors.value.filter(c => c.connected).length)

  const rateLabel = rate => `${bytes.toHuman(rate, 1, true)}B/s`
  const truncate = (text, n) => (text && text.length > n) ? `${text.slice(0, n - 1)}…` : (text || '')

  const nodes = computed(() => {
    const cy = height.value / 2
    return connectors.value.map((c, i) => {
      const y = NODE.top + i * (NODE.h + NODE.gap)
      const my = y + NODE.h / 2
      const rate = rates.value[c.id] || null
      const total = rate ? rate.in + rate.out : 0
      // Width and animation speed grow with the log of the throughput:
      // 1 kB/s is barely visible, 1 MB/s is a thick fast link.
      const magnitude = Math.log10(1 + total / 1000)
      const color = c.connected ? '#28a745' : (c.stats ? '#dc3545' : '#adb5bd')
      const flowing = c.connected && total > 0
      const stats = c.stats || {}
      const ips = (c.remote_ips || []).join(', ')
      const rtt = c.connected && stats.rtt_ms ? `${Math.round(stats.rtt_ms * 10) / 10} ms` : ''
      return {
        id: c.id,
        connected: c.connected,
        haVip: c.ha_vip ? c.ha_vip.split('/')[0] : '',
        x: NODE.x, y, w: NODE.w, h: NODE.h,
        label: truncate(c.description || c.id, 28),
        subLabel: c.connected ? (ips || i18n.t('connected')) : (c.stats ? i18n.t('tunnel down') : i18n.t('never connected')),
        color,
        path: `M ${PF.x + PF.w} ${cy} C ${PF.x + PF.w + 200} ${cy}, ${NODE.x - 200} ${my}, ${NODE.x} ${my}`,
        strokeWidth: c.connected ? 2 + Math.min(12, magnitude * 3) : 1.5,
        dash: c.connected ? (flowing ? '10 8' : null) : '4 6',
        flowing,
        flowDuration: `${Math.max(0.25, 2.5 / (1 + magnitude))}s`,
        labelX: (PF.x + PF.w + NODE.x) / 2,
        labelY: (cy + my) / 2,
        rttLabel: rtt || i18n.t('no keepalive yet'),
        rateLabel: rate ? `↓ ${rateLabel(rate.in)}  ↑ ${rateLabel(rate.out)}` : '…',
        title: [
          c.id,
          c.description,
          ips ? `${i18n.t('Addresses')}: ${ips}` : null,
          stats.connected_at ? `${i18n.t('Connected since')} ${new Date(stats.connected_at).toLocaleString()}` : null,
          stats.channels !== undefined ? `${i18n.t('Open channels')}: ${stats.channels}` : null,
          stats.bytes_in !== undefined ? `${i18n.t('Total')}: ↓ ${bytes.toHuman(stats.bytes_in, 1, true)}B ↑ ${bytes.toHuman(stats.bytes_out, 1, true)}B` : null
        ].filter(Boolean).join('\n')
      }
    })
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
    .connector-node { cursor: pointer; }
    .connector-node:hover rect { fill: #f8f9fa; }
    .link-label text { font-size: 11px; fill: #495057; paint-order: stroke; stroke: #fff; stroke-width: 3px; }
    .link-label .text-rate { fill: #6c757d; }
    path.flowing { animation: topology-flow 1s linear infinite; }
  }
  .legend-swatch { display: inline-block; width: 12px; height: 12px; border-radius: 2px; margin-right: 4px; vertical-align: middle; }
}
@keyframes topology-flow {
  from { stroke-dashoffset: 36; }
  to { stroke-dashoffset: 0; }
}
</style>
