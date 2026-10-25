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
  </b-card>
</template>
<script>
import { computed, inject } from '@vue/composition-api'

export const setup = () => {
  const remote = inject('connectorRemote')
  const { hostPackages } = remote

  const installStateClass = computed(() => {
    const state = (hostPackages.value || {}).install_state || ''
    if (/^failed/.test(state))
      return 'text-danger'
    if (/^done/.test(state))
      return 'text-success'
    return 'text-muted'
  })

  return {
    ...remote,
    installStateClass
  }
}

// @vue/component
export default {
  name: 'the-ntlm-services',
  inheritAttrs: false,
  setup
}
</script>
