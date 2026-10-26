<template>
  <div class="connector-uptime">
    <div class="d-flex align-items-center justify-content-between">
      <small class="text-muted"
        v-b-tooltip.hover.top.d300 :title="$i18n.t('Share of the measured time the connector answered PacketFence through its tunnel. Grey: no data (the connector had never connected, or PacketFence was not running).')">
        {{ $i18n.t('Availability') }}
        <template v-if="availability !== null">
          <strong :class="`text-${availabilityVariant(availability)}`">{{ formatAvailability(availability) }}</strong>
          · {{ $i18n.t('{measured} of {total} measured', { measured: formatDuration(measuredMinutes), total: formatDuration(windowMinutes) }) }}
        </template>
        <span v-else>{{ $i18n.t('no data') }}</span>
      </small>
      <b-button-group size="sm">
        <b-button v-for="w in windows" :key="w.value" class="py-0 px-1"
          :variant="w.value === uptimeWindow ? 'secondary' : 'outline-secondary'" @click="uptimeWindow = w.value">{{ w.text }}</b-button>
      </b-button-group>
    </div>
    <div class="connector-uptime-strip mt-1">
      <div v-for="(bucket, index) in buckets" :key="index"
        :class="['connector-uptime-block', `bg-${bucketVariant(bucket)}`, { 'connector-uptime-block-link': hasDowntime(bucket) }]"
        v-b-tooltip.hover.top.html.d100 :title="bucketTooltip(bucket)"
        @click="onClick(bucket)" />
    </div>
    <small v-if="error" class="text-muted">{{ error }}</small>
  </div>
</template>
<script>
import { computed, inject } from '@vue/composition-api'
import escape from 'lodash/escape'
import i18n from '@/utils/locale'
import { formatBucketTime, formatDuration, uptimeWindows } from '../_composables/useUptime'

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

export const setup = () => {
  const { goToLogs } = inject('connectorTabs')
  // the history shared by the overview cards (useUptime)
  const { uptimeWindow, windowMinutes, history, error } = inject('connectorUptime')
  const windows = uptimeWindows

  const buckets = computed(() => (history.value && history.value.buckets) || [])
  const availability = computed(() => {
    const { availability: a = null } = history.value || {}
    return a
  })
  const measuredMinutes = computed(() => {
    const { up_minutes: up = 0, down_minutes: down = 0 } = history.value || {}
    return up + down
  })

  // a day takes the colour of its worst hour
  const bucketVariant = bucket => {
    const { availability: a, worst_availability: worst } = bucket
    if (a === null)
      return 'light'
    return availabilityVariant(worst !== null && worst !== undefined ? worst : a)
  }
  // every red or orange block opens the log, from its first minute down
  const hasDowntime = bucket => ['warning', 'danger'].includes(bucketVariant(bucket))
  const downtimeStart = ({ first_down: firstDown, start }) => firstDown || start

  const formatTime = value => formatBucketTime(value, uptimeWindow.value)

  const bucketTooltip = bucket => {
    const { start, end, availability: a, worst_availability: worst, up_minutes: up, down_minutes: down, no_data_minutes: noData } = bucket
    const lines = [`<strong>${escape(formatTime(start))} – ${escape(formatTime(end))}</strong>`]
    if (a === null)
      lines.push(escape(i18n.t('No data: the connector had never connected, or PacketFence was not running.')))
    else {
      const state = { success: i18n.t('Up'), warning: i18n.t('Degraded'), danger: i18n.t('Down') }[bucketVariant(bucket)]
      lines.push(escape(`${state} · ${i18n.t('{availability} up', { availability: formatAvailability(a) })}`))
      if (worst !== null && worst !== undefined && worst < a)
        lines.push(escape(i18n.t('Worst hour: {availability} up', { availability: formatAvailability(worst) })))
      if (down >= 0.5)
        lines.push(escape(i18n.t('Tunnel down {duration} (no answer through the tunnel)', { duration: formatDuration(down) })))
      if (up >= 0.5 && down >= 0.5)
        lines.push(escape(i18n.t('Up {duration}', { duration: formatDuration(up) })))
      if (noData)
        lines.push(escape(i18n.t('No data {duration}', { duration: formatDuration(noData) })))
      if (hasDowntime(bucket))
        lines.push(`<em>${escape(i18n.t('Click to open the connector log from {time}.', { time: formatTime(downtimeStart(bucket)) }))}</em>`)
    }
    return lines.join('<br>')
  }

  const onClick = bucket => {
    if (hasDowntime(bucket))
      goToLogs('pfconnector-client', downtimeStart(bucket))
  }

  return {
    windows,
    uptimeWindow,
    error,
    buckets,
    availability,
    measuredMinutes,
    windowMinutes,
    availabilityVariant,
    formatAvailability,
    formatDuration,
    bucketVariant,
    bucketTooltip,
    hasDowntime,
    onClick
  }
}

// @vue/component
export default {
  name: 'the-uptime',
  inheritAttrs: false,
  setup
}
</script>
<style lang="scss">
.connector-uptime-strip {
  display: flex;
  height: 20px;
  .connector-uptime-block {
    flex: 1 1 0;
    min-width: 1px;
    margin-right: 1px;
    border-radius: 1px;
    &:last-child {
      margin-right: 0;
    }
    &.bg-light {
      background-color: var(--gray-300, #dee2e6) !important;
    }
    &.connector-uptime-block-link {
      cursor: pointer;
    }
  }
}
</style>
