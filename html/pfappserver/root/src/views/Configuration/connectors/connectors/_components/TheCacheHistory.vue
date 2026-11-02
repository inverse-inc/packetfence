<template>
  <div class="cache-history">
    <div class="d-flex align-items-center justify-content-between">
      <div>
        <h6 class="text-secondary mb-0">{{ $i18n.t('History') }}</h6>
        <small v-if="history" class="text-muted"
          v-b-tooltip.hover.top.d300 :title="$i18n.t('The connector samples its cache service every 10 seconds and keeps 24 hours in memory: the history starts over when the connector restarts. Each point averages the samples of {n} seconds.', { n: history.bucket_seconds })">
          {{ $i18n.t('Since {since}', { since: formatSince(history.since) }) }}
        </small>
      </div>
      <b-button-group size="sm">
        <b-button v-for="w in windows" :key="w.value" class="py-0 px-1"
          :variant="w.value === selectedWindow ? 'secondary' : 'outline-secondary'" @click="selectedWindow = w.value">{{ w.text }}</b-button>
      </b-button-group>
    </div>

    <b-alert v-if="unsupported" show variant="light" class="py-1 small mt-2 mb-0 text-muted">
      {{ $i18n.t('This remote connector does not record the history of its cache statistics. Upgrade it from the Settings tab.') }}
    </b-alert>
    <small v-else-if="error" class="text-muted d-block mt-2">{{ error }}</small>
    <small v-else-if="history && !hasSamples" class="text-muted d-block mt-2">{{ $i18n.t('No sample in this window yet.') }}</small>

    <b-row v-show="hasSamples" class="mt-2">
      <b-col md="6" class="mb-2">
        <small class="text-muted d-block">{{ $i18n.t('Cached entries') }}</small>
        <div ref="entriesRef" class="cache-history-chart"></div>
      </b-col>
      <b-col md="6" class="mb-2">
        <small class="text-muted d-block">{{ $i18n.t('Active rate-limit keys') }}</small>
        <div ref="ratelimitRef" class="cache-history-chart"></div>
      </b-col>
      <b-col md="6" class="mb-2">
        <small class="text-muted d-block">{{ $i18n.t('Database size') }}</small>
        <div ref="dbRef" class="cache-history-chart"></div>
      </b-col>
      <b-col md="6" class="mb-2">
        <small class="text-muted d-block">{{ $i18n.t('Memory') }}</small>
        <div ref="memoryRef" class="cache-history-chart"></div>
      </b-col>
    </b-row>
  </div>
</template>
<script>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import plotly, { config as plotlyConfig } from '@/utils/plotly'
import api from '../_api'

const POLL_INTERVAL = 15000

export const windows = [
  { value: '5m', text: '5m' },
  { value: '15m', text: '15m' },
  { value: '1h', text: '1h' },
  { value: '24h', text: '24h' }
]

// The series share the two colors of the tunnel traffic chart (validated
// together for color vision deficiencies); a chart with one series uses the
// first.
const colors = ['#0d6efd', '#28a745']

const layout = {
  margin: { l: 50, r: 10, t: 10, b: 30 },
  height: 180,
  paper_bgcolor: 'rgba(0,0,0,0)',
  plot_bgcolor: 'rgba(0,0,0,0)',
  hovermode: 'x unified'
}

export const props = {
  id: {
    type: String
  }
}

export const setup = props => {
  const selectedWindow = ref('1h')
  const history = ref(null)
  const error = ref(null)
  const unsupported = ref(false)

  const entriesRef = ref(null)
  const ratelimitRef = ref(null)
  const dbRef = ref(null)
  const memoryRef = ref(null)

  // One chart per unit (counts, bytes): never two scales on one axis.
  const charts = [
    {
      element: entriesRef,
      series: [
        { field: 'devices_in_db', name: i18n.t('RADIUS authorizations') },
        { field: 'credential_in_db', name: i18n.t('Credentials') }
      ]
    },
    {
      element: ratelimitRef,
      series: [{ field: 'keys_in_ratelimit', name: i18n.t('Rate-limit keys') }]
    },
    {
      element: dbRef, bytes: true,
      series: [{ field: 'db_size', name: i18n.t('Database size') }]
    },
    {
      element: memoryRef, bytes: true,
      series: [
        { field: 'mem_alloc', name: i18n.t('Allocated') },
        { field: 'mem_sys', name: i18n.t('From the OS') }
      ]
    }
  ]

  const buckets = computed(() => (history.value && history.value.buckets) || [])
  const hasSamples = computed(() => buckets.value.some(bucket => bucket.samples > 0))

  const formatSince = value => {
    const date = new Date(value)
    const sameDay = date.toDateString() === (new Date()).toDateString()
    return sameDay
      ? date.toLocaleTimeString(i18n.locale, { hour: '2-digit', minute: '2-digit' })
      : date.toLocaleString(i18n.locale, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  }

  const render = () => {
    if (!hasSamples.value)
      return
    const x = buckets.value.map(bucket => new Date(bucket.at))
    const { locale } = i18n
    const tickformat = selectedWindow.value === '24h' ? '%H:%M' : '%H:%M:%S'
    charts.forEach(chart => {
      const element = chart.element.value
      if (!element)
        return
      const data = chart.series.map((series, index) => ({
        x,
        // a bucket without sample breaks the line
        y: buckets.value.map(bucket => (bucket.samples > 0 && bucket[series.field] !== undefined) ? bucket[series.field] : null),
        name: series.name,
        type: 'scatter',
        mode: 'lines',
        connectgaps: false,
        line: { color: colors[index], width: 2 },
        hovertemplate: chart.bytes ? '%{y:.3~s}B' : '%{y:,d}'
      }))
      plotly.react(element, data, {
        ...layout,
        showlegend: chart.series.length > 1,
        legend: { orientation: 'h', y: 1.15 },
        xaxis: { type: 'date', tickformat, fixedrange: true },
        yaxis: { rangemode: 'tozero', fixedrange: true, ...(chart.bytes ? { tickformat: '~s', ticksuffix: 'B' } : { tickformat: ',d' }) }
      }, { ...plotlyConfig, displayModeBar: false, scrollZoom: false, locale })
    })
  }

  const refresh = () => {
    if (!props.id)
      return
    const requested = selectedWindow.value
    api.remoteCacheHistory(props.id, requested).then(data => {
      if (requested !== selectedWindow.value)
        return
      history.value = data
      error.value = null
      unsupported.value = false
      nextTick(render)
    }).catch(err => {
      const { response: { status } = {} } = err || {}
      if (status === 404)
        unsupported.value = true
      else
        error.value = i18n.t('Cache history unavailable.')
    })
  }

  let interval = null
  onMounted(() => {
    refresh()
    interval = setInterval(refresh, POLL_INTERVAL)
    window.addEventListener('resize', render)
  })
  onBeforeUnmount(() => {
    if (interval)
      clearInterval(interval)
    window.removeEventListener('resize', render)
    charts.forEach(chart => {
      if (chart.element.value)
        plotly.purge(chart.element.value)
    })
  })
  watch(selectedWindow, () => {
    history.value = null
    refresh()
  })
  watch(() => i18n.locale, () => nextTick(render))

  return {
    windows,
    selectedWindow,
    history,
    error,
    unsupported,
    hasSamples,
    formatSince,
    entriesRef,
    ratelimitRef,
    dbRef,
    memoryRef
  }
}

// @vue/component
export default {
  name: 'the-cache-history',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.cache-history-chart {
  width: 100%;
  min-height: 180px;
}
</style>
