<template>
  <div class="connector-uptime">
    <div class="d-flex align-items-center justify-content-between">
      <small class="text-muted"
        v-b-tooltip.hover.top.d300 :title="$i18n.t('Share of the time the connector answered PacketFence through its tunnel. Grey: no data (the connector had never connected, or PacketFence was not running).')">
        {{ $i18n.t('Availability') }}
        <strong v-if="availability !== null" :class="`text-${availabilityVariant(availability)}`">{{ formatAvailability(availability) }}</strong>
        <span v-else>-</span>
      </small>
      <b-button-group size="sm">
        <b-button v-for="w in windows" :key="w.value" class="py-0 px-1"
          :variant="w.value === uptimeWindow ? 'secondary' : 'outline-secondary'" @click="uptimeWindow = w.value">{{ w.text }}</b-button>
      </b-button-group>
    </div>
    <div ref="chartRef" class="connector-uptime-chart mt-1" />
    <small v-if="error" class="text-muted">{{ error }}</small>
  </div>
</template>
<script>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import plotly, { config as plotlyConfig } from '@/utils/plotly'
import api from '../_api'

const POLL_INTERVAL = 60000

// bootstrap success / warning / danger / gray-300
const colors = {
  success: '#28a745',
  warning: '#ffc107',
  danger: '#dc3545',
  none: '#dee2e6'
}

// up, partially up (some downtime), down
export const availabilityVariant = availability => {
  if (availability >= 0.999)
    return 'success'
  if (availability >= 0.01)
    return 'warning'
  return 'danger'
}

export const formatAvailability = availability => {
  const percent = availability * 100
  return `${(percent === 100 || percent < 99.9) ? percent.toFixed(1) : percent.toFixed(2)}%`
}

export const props = {
  id: {
    type: String
  }
}

export const setup = props => {
  const windows = [
    { value: '1h', text: i18n.t('1h') },
    { value: '24h', text: i18n.t('24h') },
    { value: '30d', text: i18n.t('30d') }
  ]
  const uptimeWindow = ref('24h')
  const history = ref(null)
  const error = ref(null)
  const chartRef = ref(null)

  const availability = computed(() => {
    const { availability: a = null } = history.value || {}
    return a
  })

  const bucketLabel = ({ start, end }) => {
    const [s, e] = [new Date(start), new Date(end)]
    if (uptimeWindow.value === '30d')
      return `${s.toLocaleDateString(i18n.locale)} ${s.toLocaleTimeString(i18n.locale, { hour: '2-digit', minute: '2-digit' })} – ${e.toLocaleDateString(i18n.locale)} ${e.toLocaleTimeString(i18n.locale, { hour: '2-digit', minute: '2-digit' })}`
    return `${s.toLocaleTimeString(i18n.locale, { hour: '2-digit', minute: '2-digit' })} – ${e.toLocaleTimeString(i18n.locale, { hour: '2-digit', minute: '2-digit' })}`
  }

  const bucketText = bucket => {
    const { availability: a, down_minutes: down, no_data_minutes: noData } = bucket
    const lines = [bucketLabel(bucket)]
    if (a === null)
      lines.push(i18n.t('No data'))
    else {
      lines.push(i18n.t('{availability} up', { availability: formatAvailability(a) }))
      if (down >= 0.5)
        lines.push(i18n.t('Down {minutes} min', { minutes: Math.round(down) }))
      if (noData)
        lines.push(i18n.t('No data {minutes} min', { minutes: noData }))
    }
    return lines.join('<br>')
  }

  const render = () => {
    if (!chartRef.value || !history.value)
      return
    const { buckets = [] } = history.value
    plotly.react(chartRef.value, [{
      type: 'bar',
      x: buckets.map((_, index) => index),
      y: buckets.map(() => 1),
      marker: { color: buckets.map(({ availability: a }) => a === null ? colors.none : colors[availabilityVariant(a)]) },
      hovertext: buckets.map(bucketText),
      hoverinfo: 'text'
    }], {
      height: 28,
      margin: { l: 0, r: 0, t: 0, b: 0 },
      bargap: 0.15,
      paper_bgcolor: 'rgba(0,0,0,0)',
      plot_bgcolor: 'rgba(0,0,0,0)',
      showlegend: false,
      xaxis: { visible: false, fixedrange: true },
      yaxis: { visible: false, fixedrange: true, range: [0, 1] }
    }, { ...plotlyConfig, displayModeBar: false, scrollZoom: false, locale: i18n.locale })
  }

  const refresh = () => {
    if (!props.id)
      return
    const requested = uptimeWindow.value
    api.remoteUptime(props.id, requested).then(data => {
      if (requested !== uptimeWindow.value)
        return
      history.value = data
      error.value = null
      nextTick(render)
    }).catch(() => {
      error.value = i18n.t('Uptime history unavailable.')
    })
  }

  let interval = null
  onMounted(() => {
    refresh()
    interval = setInterval(refresh, POLL_INTERVAL)
  })
  onBeforeUnmount(() => {
    if (interval)
      clearInterval(interval)
    if (chartRef.value)
      plotly.purge(chartRef.value)
  })
  watch(uptimeWindow, refresh)

  return {
    windows,
    uptimeWindow,
    error,
    chartRef,
    availability,
    availabilityVariant,
    formatAvailability
  }
}

// @vue/component
export default {
  name: 'the-uptime',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.connector-uptime-chart {
  height: 28px;
}
</style>
