<template>
  <b-tab>
    <template #title>
      {{ $i18n.t('Overview') }}
      <b-badge v-if="attentionCount" pill variant="warning" class="ml-1">{{ attentionCount }}</b-badge>
    </template>
    <b-row>
      <b-col md="4" class="mb-3">
        <b-card class="h-100">
          <small class="text-muted">{{ $i18n.t('Tunnel') }}</small>
          <h5 class="mt-1 mb-1">
            <b-badge :variant="isConnected ? 'success' : (status ? 'danger' : 'secondary')">
              {{ isConnected ? $i18n.t('Connected') : (status ? $i18n.t('Disconnected') : $i18n.t('Status unavailable')) }}
            </b-badge>
          </h5>
          <small class="text-muted">
            {{ $i18n.t('Host IP(s)') }}: <span class="text-monospace">{{ hostIps || '-' }}</span>
          </small>
        </b-card>
      </b-col>
      <b-col md="4" class="mb-3">
        <b-card class="h-100">
          <small class="text-muted">{{ $i18n.t('Version') }}</small>
          <h5 class="mt-1 mb-1">
            {{ (system && system.version) || '-' }}
            <b-badge v-if="status && status.upgrade_available" variant="warning" class="ml-1">
              {{ $i18n.t('{version} available', { version: status.central_version }) }}
            </b-badge>
          </h5>
          <small v-if="status && status.central_version" class="text-muted">
            {{ $i18n.t('PacketFence is {version}', { version: status.central_version }) }}
          </small>
        </b-card>
      </b-col>
      <b-col md="4" class="mb-3">
        <b-card class="h-100">
          <small class="text-muted">{{ $i18n.t('Site DNS') }}</small>
          <h5 class="mt-1 mb-1">{{ $i18n.t('{count} server(s)', { count: dnsConnectors.length }) }}</h5>
          <small v-for="dns in dnsConnectors" :key="dns.id" class="d-block text-muted">
            {{ (dns.domains || []).join(', ') }} {{ $i18n.t('via') }} <span class="text-monospace">{{ dns.ip }}</span>
          </small>
        </b-card>
      </b-col>
    </b-row>

    <b-card class="mb-3" no-body>
      <b-card-body v-if="system" class="py-2">
        <b-row class="text-nowrap">
          <b-col class="py-1">
            <strong>{{ system.cpu_count }} · {{ formatPercent(system.cpu_usage_percent) }}</strong>
            <div class="small text-muted">{{ $i18n.t('CPU (cores · usage)') }}</div>
          </b-col>
          <b-col class="py-1">
            <strong>{{ formatBytes(system.mem_used) }} / {{ formatBytes(system.mem_total) }}</strong>
            <div class="small text-muted">{{ $i18n.t('Memory') }} · {{ formatPercent(system.mem_usage_percent) }}</div>
          </b-col>
          <b-col class="py-1">
            <strong>{{ formatBytes(system.disk_used) }} / {{ formatBytes(system.disk_total) }}</strong>
            <div class="small text-muted">{{ $i18n.t('Disk') }} / · {{ formatPercent(system.disk_usage_percent) }}</div>
          </b-col>
          <b-col class="py-1">
            <strong>{{ formatLoad(system.load1) }} / {{ formatLoad(system.load5) }} / {{ formatLoad(system.load15) }}</strong>
            <div class="small text-muted">{{ $i18n.t('Load (1/5/15m)') }}</div>
          </b-col>
          <b-col class="py-1">
            <strong>{{ formatUptime(system.uptime_seconds) }}</strong>
            <div class="small text-muted">{{ $i18n.t('Uptime') }}</div>
          </b-col>
          <b-col class="py-1">
            <strong>{{ system.hostname }}</strong>
            <div class="small text-muted">{{ $i18n.t('Hostname') }}</div>
          </b-col>
        </b-row>
      </b-card-body>
      <b-card-body v-else class="py-2 text-muted">
        {{ isConnected ? $i18n.t('System information unavailable.') : $i18n.t('System information is reported while the tunnel is connected.') }}
      </b-card-body>
    </b-card>

    <the-high-availability v-if="ha" class="mb-3" />

    <b-row v-if="hostPackages">
      <b-col md="6" class="mb-3">
        <the-ntlm-services />
      </b-col>
    </b-row>

    <b-card no-body>
      <b-card-header>
        <h6 class="mb-0">{{ $i18n.t('Needs attention') }}</h6>
      </b-card-header>
      <b-list-group flush>
        <b-list-group-item v-if="status && status.upgrade_available" class="d-flex align-items-center justify-content-between">
          <span>{{ $i18n.t('Update available: PacketFence is {central}, this connector runs {version}.', { central: status.central_version, version: system ? system.version : '-' }) }}</span>
          <b-button v-if="canUpdate" size="sm" variant="outline-primary" :disabled="!isConnected || isUpgrading" @click="showUpgradeModal = true">{{ $i18n.t('Update...') }}</b-button>
        </b-list-group-item>
        <b-list-group-item v-for="(error, index) in errors" :key="`error-${index}`" variant="warning">
          {{ error }}
        </b-list-group-item>
        <b-list-group-item v-for="connection in unboundStaticConnections" :key="`static-${connection.local_proto}-${connection.local_port}`" class="d-flex align-items-center justify-content-between">
          <span>
            {{ $i18n.t('Static connection not bound') }}:
            <span class="text-monospace">{{ connection.local_port }}/{{ connection.local_proto }} → {{ connection.remote_host }}:{{ connection.remote_port }}</span>
          </span>
          <b-button size="sm" variant="outline-secondary" @click="goToTab('networking')">{{ $i18n.t('Open networking') }}</b-button>
        </b-list-group-item>
        <b-list-group-item v-if="ha && !haPeersAlive.length" variant="warning">
          {{ $i18n.t('High availability: no backup host is reporting to the master, a failure of this host would interrupt the service.') }}
        </b-list-group-item>
        <b-list-group-item v-for="(error, index) in siteNetworkErrors" :key="`site-${index}`" class="d-flex align-items-center justify-content-between">
          <span>{{ error }}</span>
          <b-button size="sm" variant="outline-secondary" @click="goToSiteNetwork">{{ $i18n.t('Open networking') }}</b-button>
        </b-list-group-item>
        <b-list-group-item v-if="!attentionCount" class="text-muted">
          {{ $i18n.t('Nothing needs attention.') }}
        </b-list-group-item>
      </b-list-group>
    </b-card>
  </b-tab>
</template>
<script>
import { computed, inject } from '@vue/composition-api'
import TheHighAvailability from './TheHighAvailability'
import TheNtlmServices from './TheNtlmServices'
import {
  formatBytes,
  formatLoad,
  formatPercent,
  formatUptime
} from '../_composables/useRemoteStatus'

const components = {
  TheHighAvailability,
  TheNtlmServices
}

export const setup = () => {
  const remote = inject('connectorRemote')
  const { goToTab, goToSiteNetwork } = inject('connectorTabs')
  const { status } = remote

  const hostIps = computed(() => {
    const { remote_ips: ips = [] } = status.value || {}
    return (ips || []).join(', ')
  })

  return {
    ...remote,
    goToTab,
    goToSiteNetwork,
    hostIps,
    formatBytes,
    formatLoad,
    formatPercent,
    formatUptime
  }
}

// @vue/component
export default {
  name: 'tab-overview',
  inheritAttrs: false,
  components,
  setup
}
</script>
