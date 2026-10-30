<template>
  <b-card>
    <h6>{{ $i18n.t('Connector Services') }}</h6>
    <p class="small text-muted">
      {{ $i18n.t('The services running in the connector itself. A restart takes effect within a few seconds and does not interrupt the tunnel; RADIUS requests received while FreeRADIUS restarts are retried by the equipment.') }}
    </p>
    <b-table-simple small class="mb-0">
      <b-tbody>
        <b-tr v-for="svc in containerServices" :key="svc.name">
          <b-td :title="svc.description">
            {{ serviceLabel(svc) }}
            <small class="text-monospace text-muted ml-1">{{ svc.name }}</small>
          </b-td>
          <b-td>
            <b-badge v-if="svc.error" variant="secondary" :title="svc.error">{{ $i18n.t('unknown') }}</b-badge>
            <template v-else-if="svc.up">
              <b-badge variant="success">{{ $i18n.t('running') }}</b-badge>
              <small class="text-muted ml-1">{{ $i18n.t('for {duration}', { duration: formatDuration(svc.since_seconds) }) }}<template v-if="svc.pid">, PID {{ svc.pid }}</template></small>
            </template>
            <template v-else>
              <b-badge :variant="svc.wanted_up ? 'warning' : 'danger'">{{ svc.wanted_up ? $i18n.t('starting') : $i18n.t('stopped') }}</b-badge>
              <small class="text-muted ml-1">{{ $i18n.t('for {duration}', { duration: formatDuration(svc.since_seconds) }) }}<template v-if="svc.signal">, {{ $i18n.t('killed by {signal}', { signal: svc.signal }) }}</template><template v-else-if="svc.exit_code !== undefined">, {{ $i18n.t('exit code {code}', { code: svc.exit_code }) }}</template></small>
            </template>
          </b-td>
          <b-td class="text-right text-nowrap">
            <b-button v-if="canUpdate && !svc.error" size="sm" variant="outline-secondary" class="py-0"
              :disabled="!isConnected || !!actingContainerService"
              :title="$i18n.t('Restart {service}', { service: serviceLabel(svc) })"
              @click="onContainerServiceRestart(svc.name)">
              <icon v-if="actingContainerService === svc.name" name="circle-notch" spin /><icon v-else name="redo" />
            </b-button>
          </b-td>
        </b-tr>
      </b-tbody>
    </b-table-simple>
  </b-card>
</template>
<script>
import { inject } from '@vue/composition-api'
import i18n from '@/utils/locale'

// the services of the connector container, by s6 service name
const LABELS = {
  'radiusd-auth': 'FreeRADIUS',
  'connector-cache': 'RADIUS Cache'
}

export const setup = () => {
  const remote = inject('connectorRemote')

  const serviceLabel = svc => LABELS[svc.name] || svc.name
  const formatDuration = seconds => {
    const s = Math.max(0, Math.floor(seconds || 0))
    if (s < 60)
      return i18n.t('{count}s', { count: s })
    if (s < 3600)
      return i18n.t('{count}m', { count: Math.floor(s / 60) })
    if (s < 86400)
      return i18n.t('{hours}h {minutes}m', { hours: Math.floor(s / 3600), minutes: Math.floor((s % 3600) / 60) })
    return i18n.t('{days}d {hours}h', { days: Math.floor(s / 86400), hours: Math.floor((s % 86400) / 3600) })
  }

  return {
    ...remote,
    serviceLabel,
    formatDuration
  }
}

// @vue/component
export default {
  name: 'the-connector-services',
  inheritAttrs: false,
  setup
}
</script>
