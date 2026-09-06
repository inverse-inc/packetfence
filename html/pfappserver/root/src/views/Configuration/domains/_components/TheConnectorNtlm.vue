<template>
  <b-form-group label-cols="3" v-if="visible">
    <b-alert show :variant="alertVariant" class="mb-0">
      <template v-if="isLooking">
        <icon name="circle-notch" spin class="mr-1" />{{ $i18n.t('Looking up the connector serving {ip}...', { ip: adServer }) }}
      </template>
      <template v-else-if="lookupError">
        {{ lookupError }}
      </template>
      <template v-else-if="connectorId">
        <p class="mb-1">
          <strong>{{ $i18n.t('Connector') }}</strong>
          <router-link :to="{ name: 'connectorsConnector', params: { id: connectorId } }" class="text-monospace ml-1">{{ connectorId }}</router-link>
          {{ $i18n.t('serves {ip}.', { ip: adServer }) }}
          <b-badge v-if="remote" :variant="remote.connected ? 'success' : 'danger'" class="ml-1">{{ remote.connected ? $i18n.t('Connected') : $i18n.t('Disconnected') }}</b-badge>
        </p>
        <p class="mb-1">
          {{ $i18n.t('Joining a domain behind a connector needs the NTLM authentication services on the connector host (packetfence-ntlm-auth-join-remote and packetfence-ntlm-auth-api-remote).') }}
        </p>
        <template v-if="hostPackages">
          <p class="mb-1">
            <template v-if="!hostPackages.available">
              <b-badge variant="secondary">{{ $i18n.t('package state unknown') }}</b-badge>
              <small class="text-muted ml-1">{{ $i18n.t('(older connector package on the host)') }}</small>
            </template>
            <template v-else>
              <b-badge v-for="pkg in hostPackages.packages" :key="pkg.name" :variant="pkg.installed ? 'success' : 'light'" :class="{ border: !pkg.installed }" class="mr-1">
                {{ pkg.name }}: {{ pkg.installed ? $i18n.t('installed') : $i18n.t('not installed') }}
              </b-badge>
            </template>
            <b-badge :variant="hostPackages.ntlm_join_remote_listening ? 'success' : 'warning'" class="mr-1">
              {{ $i18n.t('join service') }}: {{ hostPackages.ntlm_join_remote_listening ? $i18n.t('running') : $i18n.t('not running') }}
            </b-badge>
          </p>
          <p v-if="hostPackages.install_state" class="mb-1 small text-muted">{{ $i18n.t('Last install request') }}: {{ hostPackages.install_state }}</p>
          <b-button v-if="!installed" size="sm" variant="primary" :disabled="!remote || !remote.connected || isInstalling || installInProgress" @click="install">
            <icon name="download" class="mr-1" />{{ $i18n.t('Install NTLM Services on the connector host') }}
          </b-button>
          <small v-else class="text-success">{{ $i18n.t('The NTLM authentication services are installed on the connector host; the domain can be joined.') }}</small>
        </template>
        <small v-else class="text-muted">{{ $i18n.t('The connector status is not available.') }}</small>
      </template>
    </b-alert>
  </b-form-group>
</template>
<script>
import { computed, onBeforeUnmount, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import connectorsApi from '../../connectors/connectors/_api'

const props = {
  // The Active Directory server IP entered in the form.
  adServer: {
    type: String
  },
  // Whether the domain is reached through a connector.
  useConnector: {
    type: [Boolean, String, Number]
  }
}

const reIPv4 = /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/

const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const enabled = computed(() => ['1', 1, true, 'enabled'].includes(props.useConnector))
  const validIp = computed(() => reIPv4.test(props.adServer || ''))
  const visible = computed(() => enabled.value && validIp.value)

  const isLooking = ref(false)
  const lookupError = ref(null)
  const connectorId = ref(null)
  const remote = ref(null)
  const isInstalling = ref(false)
  let debounce = null
  let poll = null

  const hostPackages = computed(() => {
    const { system: { host_packages: hp } = {} } = remote.value || {}
    return (hp && hp.packages) ? hp : null
  })
  const installed = computed(() => {
    const hp = hostPackages.value
    return !!hp && hp.available && hp.packages.every(pkg => pkg.installed)
  })
  const installInProgress = computed(() => /^(requested|installing)/.test((hostPackages.value || {}).install_state || ''))
  const alertVariant = computed(() => {
    if (lookupError.value) return 'warning'
    if (installed.value) return 'success'
    return 'info'
  })

  const refreshRemote = () => {
    if (!connectorId.value) return Promise.resolve()
    return connectorsApi.remoteStatus(connectorId.value).then(response => {
      remote.value = response
    }).catch(() => {
      remote.value = null
    })
  }

  const lookup = () => {
    lookupError.value = null
    connectorId.value = null
    remote.value = null
    if (!visible.value) return
    isLooking.value = true
    connectorsApi.forIp(props.adServer).then(response => {
      connectorId.value = response.connector_id
      return refreshRemote()
    }).catch(() => {
      lookupError.value = i18n.t('No connector serves {ip}: add this network to a connector first, or the domain cannot be reached.', { ip: props.adServer })
    }).finally(() => {
      isLooking.value = false
    })
  }

  watch([() => props.adServer, enabled], () => {
    if (debounce) clearTimeout(debounce)
    debounce = setTimeout(lookup, 600)
  }, { immediate: true })

  const install = () => {
    isInstalling.value = true
    connectorsApi.remoteInstall(connectorId.value, ['packetfence-ntlm-auth-join-remote']).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Install started on the connector host; the state below updates as it progresses. Join the domain once the services are installed.') })
      let polls = 0
      if (poll) clearInterval(poll)
      poll = setInterval(() => {
        refreshRemote()
        if (++polls >= 30 || installed.value) {
          clearInterval(poll)
          poll = null
        }
      }, 10000)
    }).catch(() => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to trigger the install on the connector host.') })
    }).finally(() => {
      isInstalling.value = false
      setTimeout(refreshRemote, 3000)
    })
  }

  onBeforeUnmount(() => {
    if (debounce) clearTimeout(debounce)
    if (poll) clearInterval(poll)
  })

  return {
    visible,
    isLooking,
    lookupError,
    connectorId,
    remote,
    hostPackages,
    installed,
    installInProgress,
    isInstalling,
    alertVariant,
    install
  }
}

// @vue/component
export default {
  name: 'the-connector-ntlm',
  props,
  setup
}
</script>
