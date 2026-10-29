<template>
  <b-card class="h-100">
    <h6>{{ $i18n.t('NTLM Authentication Services') }}</h6>
    <p class="small text-muted">
      {{ $i18n.t('Needed on this host when an Active Directory domain is behind the connector: the join service creates the machine account and the API service answers NTLM authentications locally.') }}
    </p>
    <b-table-simple small class="mb-1">
      <b-tbody>
        <b-tr v-for="pkg in hostPackages.packages" :key="pkg.name">
          <b-td class="text-monospace">{{ pkg.name }}</b-td>
          <b-td>
            <b-badge v-if="!hostPackages.available" variant="secondary">{{ $i18n.t('unknown') }}</b-badge>
            <b-badge v-else-if="pkg.installed" variant="success">{{ $i18n.t('installed') }} <small>{{ pkg.version }}</small></b-badge>
            <b-badge v-else variant="light" class="border">{{ $i18n.t('not installed') }}</b-badge>
          </b-td>
        </b-tr>
        <b-tr>
          <b-td class="text-muted">{{ $i18n.t('Join service') }}</b-td>
          <b-td>
            <b-badge :variant="hostPackages.ntlm_join_remote_listening ? 'success' : 'light'" :class="{ border: !hostPackages.ntlm_join_remote_listening }">
              {{ hostPackages.ntlm_join_remote_listening ? $i18n.t('running') : $i18n.t('not running') }}
            </b-badge>
          </b-td>
        </b-tr>
      </b-tbody>
    </b-table-simple>
    <p v-if="hostPackages.install_state" class="mb-1 small" :class="installStateClass">
      {{ $i18n.t('Last install request') }}: {{ hostPackages.install_state }}
    </p>
    <b-button v-if="!ntlmInstalled && canUpdate" size="sm" variant="outline-primary"
      :disabled="!isConnected || isInstalling || installInProgress"
      :title="!hostPackages.available ? $i18n.t('The host package state is unknown (older connector package); the install can still be requested.') : ''"
      @click="showNtlmInstallModal = true">
      <icon name="download" class="mr-1" />{{ $i18n.t('Install NTLM Services...') }}
    </b-button>

    <template v-if="hostServices">
      <h6 class="mt-3 mb-1">{{ $i18n.t('Services on the host') }}
        <small v-if="hostServices.stale" class="text-muted font-weight-normal ml-2"><icon name="circle-notch" spin class="mr-1" />{{ $i18n.t('refreshing') }}</small>
      </h6>
      <b-table-simple small class="mb-1">
        <b-tbody>
          <b-tr v-for="svc in hostServices.services" :key="svc.name">
            <b-td class="text-monospace small" :title="svc.description">{{ svc.name }}</b-td>
            <b-td>
              <b-badge v-if="!svc.installed" variant="light" class="border">{{ $i18n.t('not installed') }}</b-badge>
              <b-badge v-else :variant="serviceVariant(svc)" :class="{ border: serviceVariant(svc) === 'light' }" :title="svc.since">
                {{ serviceLabel(svc) }}
              </b-badge>
              <small v-if="svc.restarts" class="ml-1" :class="svc.restarts > 3 ? 'text-danger' : 'text-muted'">{{ $i18n.t('{count} restart(s)', { count: svc.restarts }) }}</small>
            </b-td>
            <b-td class="text-right text-nowrap">
              <template v-if="canUpdate && svc.installed">
                <b-button v-if="!isServiceActive(svc)" size="sm" variant="outline-success" class="py-0"
                  :disabled="!isConnected || !!actingService" :title="$i18n.t('Start')"
                  @click="onServiceAction(svc.name, 'start')">
                  <icon v-if="isActing(svc, 'start')" name="circle-notch" spin /><icon v-else name="play" />
                </b-button>
                <template v-else>
                  <b-button size="sm" variant="outline-secondary" class="py-0 mr-1"
                    :disabled="!isConnected || !!actingService" :title="$i18n.t('Restart')"
                    @click="onServiceAction(svc.name, 'restart')">
                    <icon v-if="isActing(svc, 'restart')" name="circle-notch" spin /><icon v-else name="redo" />
                  </b-button>
                  <b-button size="sm" variant="outline-danger" class="py-0"
                    :disabled="!isConnected || !!actingService" :title="$i18n.t('Stop')"
                    @click="onServiceAction(svc.name, 'stop')">
                    <icon v-if="isActing(svc, 'stop')" name="circle-notch" spin /><icon v-else name="stop" />
                  </b-button>
                </template>
              </template>
            </b-td>
          </b-tr>
          <b-tr v-if="!hostServices.services.length">
            <b-td class="text-muted small">{{ $i18n.t('No NTLM service on this host.') }}</b-td>
          </b-tr>
        </b-tbody>
      </b-table-simple>
      <p v-if="hostServices.last_action" class="mb-1 small" :class="lastActionClass">
        {{ $i18n.t('Last action') }}: {{ hostServices.last_action.action }} {{ hostServices.last_action.unit }}, {{ hostServices.last_action.result }}<template v-if="hostServices.last_action.message">: {{ hostServices.last_action.message }}</template>
      </p>
    </template>
    <p v-else-if="ntlmInstalled" class="mt-3 mb-1 small text-muted">
      {{ $i18n.t('The state of the services has not been received from the host yet (a connector package predating their management from here never reports it).') }}
    </p>
  </b-card>
</template>
<script>
import { computed, inject } from '@vue/composition-api'
import i18n from '@/utils/locale'

// systemd ActiveState values during which a unit counts as running (stop and
// restart offered) rather than stopped (start offered).
const ACTIVE_STATES = ['active', 'activating', 'reloading']

export const setup = () => {
  const remote = inject('connectorRemote')
  const { hostPackages, hostServices, actingService } = remote

  const installStateClass = computed(() => {
    const state = (hostPackages.value || {}).install_state || ''
    if (/^failed/.test(state))
      return 'text-danger'
    if (/^done/.test(state))
      return 'text-success'
    return 'text-muted'
  })

  const isServiceActive = svc => ACTIVE_STATES.includes(svc.active_state)
  const isActing = (svc, action) => {
    const acting = actingService.value
    return !!acting && acting.service === svc.name && acting.action === action
  }
  // A unit in "activating (auto-restart)" is a crash loop: systemd restarts
  // it over and over, it never reaches "active".
  const serviceVariant = svc => {
    if (svc.active_state === 'active')
      return 'success'
    if (svc.active_state === 'failed' || svc.sub_state === 'auto-restart')
      return 'danger'
    if (svc.active_state === 'activating' || svc.active_state === 'deactivating')
      return 'warning'
    return 'light'
  }
  const serviceLabel = svc => {
    if (svc.active_state === 'active' && svc.sub_state === 'running')
      return i18n.t('running')
    if (svc.active_state === 'inactive')
      return i18n.t('stopped')
    if (svc.sub_state === 'auto-restart')
      return i18n.t('crash loop')
    return svc.sub_state ? `${svc.active_state} (${svc.sub_state})` : svc.active_state
  }
  const lastActionClass = computed(() => {
    const { result } = (hostServices.value || {}).last_action || {}
    return result === 'ok' ? 'text-success' : (result === 'failed' ? 'text-danger' : 'text-muted')
  })

  return {
    ...remote,
    installStateClass,
    isServiceActive,
    isActing,
    serviceVariant,
    serviceLabel,
    lastActionClass
  }
}

// @vue/component
export default {
  name: 'the-ntlm-services',
  inheritAttrs: false,
  setup
}
</script>
