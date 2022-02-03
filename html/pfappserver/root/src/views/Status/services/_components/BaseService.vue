<template>
  <b-overlay :show="service.status && !['success', 'error'].includes(service.status)">
    <b-container fluid>
      <b-row class="row-nowrap" align-v="start">
        <b-col cols="6">
          <b-row class="row-nowrap">
            <b-col>{{ $t('Alive') }}</b-col>
            <b-col cols="auto">
              <b-badge v-if="service.alive && service.pid" pill variant="success">{{ service.pid }}</b-badge>
              <icon v-else class="text-danger" name="circle"/>
            </b-col>
          </b-row>
          <b-row class="row-nowrap">
            <b-col>{{ $t('Enabled') }}</b-col>
            <b-col cols="auto"><icon :class="(service.enabled) ? 'text-success' : 'text-danger'" name="circle"/></b-col>
          </b-row>
          <b-row class="row-nowrap">
            <b-col>{{ $t('Managed') }}</b-col>
            <b-col cols="auto"><icon :class="(service.managed) ? 'text-success' : 'text-danger'" name="circle"/></b-col>
          </b-row>
        </b-col>
        <b-col cols="6" v-if="!isBlacklisted && isAllowed">
          <template>
            <b-button v-if="!service.enabled"
              @click="doEnable(server)" :disabled="isLoading" variant="link" size="sm" class="text-secondary mr-1">
              <icon name="toggle-on" class="mr-1" /> {{ $t('Enable') }}
            </b-button>
            <b-button v-if="service.enabled"
              @click="doDisable(server)" :disabled="isLoading" variant="link" size="sm" class="text-secondary mr-1">
              <icon name="toggle-off" class="mr-1" /> {{ $t('Disable') }}
            </b-button>
            <b-button v-if="service.alive && service.pid"
              @click="doRestart(server)" :disabled="isLoading" variant="link" size="sm" class="text-secondary mr-1">
              <icon name="redo" class="mr-1" /> {{ $t('Restart') }}
            </b-button>
            <b-button v-if="!(service.alive && service.pid)"
              @click="doStart(server)" :disabled="isLoading" variant="link" size="sm" class="text-secondary mr-1">
              <icon name="play" class="mr-1" /> {{ $t('Start') }}
            </b-button>
            <b-button v-if="service.alive && service.pid"
              @click="doStop(server)" :disabled="isLoading" variant="link" size="sm" class="text-secondary mr-1">
              <icon name="stop" class="mr-1" /> {{ $t('Stop') }}
            </b-button>
          </template>
        </b-col>
      </b-row>
      <b-alert v-if="service.message && ['success', 'error'].includes(service.status)"
        show class="small mb-0" :class="(service.status === 'error') ? 'text-danger' : 'text-secondary'">
        {{ service.message }}
      </b-alert>
    </b-container>
    <template v-slot:overlay v-if="service.status && !['loading'].includes(service.status)">
      <b-media class="text-uppercase font-weight-bold">
        <template v-slot:aside><icon name="circle-notch" spin scale="1.5" /></template>
        <h6 v-if="service.status === 'disabling'" class="my-2">{{ $i18n.t('Disabling') }}</h6>
        <h6 v-if="service.status === 'enabling'" class="my-2">{{ $i18n.t('Enabling') }}</h6>
        <h6 v-if="service.status === 'restarting'" class="my-2">{{ $i18n.t('Restarting') }}</h6>
        <h6 v-if="service.status === 'starting'" class="my-2">{{ $i18n.t('Starting') }}</h6>
        <h6 v-if="service.status === 'stopping'" class="my-2">{{ $i18n.t('Stopping') }}</h6>
      </b-media>
    </template>
  </b-overlay>
</template>
<script>
const props = {
  id: {
    type: String
  },
  server: {
    type: String
  },
  disabled: {
    type: Boolean
  },
  acl: {
    type: String,
    default: 'SERVICES_READ'
  },
  lazy: {
    type: Boolean
  }
}

import { computed, toRefs, watch } from '@vue/composition-api'
import { blacklistedServices } from '@/store/modules/services'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const {
    id,
    server,
    disabled,
    lazy,
    acl: _acl
  } = toRefs(props)

  const { emit, root: { $store } = {} } = context

  const isAllowed = computed(() => {
    if (_acl.value) {
      const [ verb, ...nouns ] = Array.prototype.slice.call(_acl.value.toLowerCase().split('_')).reverse()
      const noun = nouns.reverse().join('_')
      return verb && nouns.length > 0 && acl.$can(verb, noun)
    }
    return true
  })

  watch([id, server], () => {
    if (isAllowed.value && !lazy.value) {
      $store.dispatch('cluster/getService', { server: server.value, id: id.value })
    }
  }, { immediate: true })
  const service = computed(() => $store.state.cluster.servers[server.value].services[id.value])

  const isBlacklisted = computed(() => !!blacklistedServices.find(bls => bls === id.value))
  const isCluster = computed(() => $store.getters['cluster/isCluster'])
  const isLoading = computed(() => $store.getters['cluster/isLoading'])
  const isDisabled = computed(() => disabled.value || !isAllowed.value)

  const doEnable = () => $store.dispatch('cluster/enableService', { server: server.value, id: id.value }).then(() => {
    $store.dispatch('notification/info', { url: server.value, message: i18n.t('Service <code>{service}</code> enabled.', { service: id.value }) })
    emit('enable', { server, id: id.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server.value, message: i18n.t('Failed to enable service <code>{service}</code>. See the server error logs for more information.', { service: id.value }) })
  })

  const doDisable = () => $store.dispatch('cluster/disableService', { server: server.value, id: id.value }).then(() => {
    $store.dispatch('notification/info', { url: server.value, message: i18n.t('Service <code>{service}</code> disabled.', { service: id.value }) })
    emit('disable', { server, id: id.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server.value, message: i18n.t('Failed to disable service <code>{service}</code>. See the server error logs for more information.', { service: id.value }) })
  })

  const doRestart = () => $store.dispatch('cluster/restartService', { server: server.value, id: id.value }).then(() => {
    $store.dispatch('notification/info', { url: server.value, message: i18n.t('Service <code>{service}</code> restarted.', { service: id.value }) })
    emit('restart', { server, id: id.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server.value, message: i18n.t('Failed to restart service <code>{service}</code>.  See the server error logs for more information.', { service: id.value }) })
  })

  const doStart = () => $store.dispatch('cluster/startService', { server: server.value, id: id.value }).then(() => {
    $store.dispatch('notification/info', { url: server.value, message: i18n.t('Service <code>{service}</code> started.', { service: id.value }) })
    emit('start', { server, id: id.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server.value, message: i18n.t('Failed to start service <code>{service}</code>.  See the server error logs for more information.', { service: id.value }) })
  })

  const doStop = () => $store.dispatch('cluster/stopService', { server: server.value, id: id.value }).then(() => {
    $store.dispatch('notification/info', { url: server.value, message: i18n.t('Service <code>{service}</code> killed.', { service: id.value }) })
    emit('stop', { server, id: id.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server.value, message: i18n.t('Failed to kill service <code>{service}</code>.  See the server error logs for more information.s', { service: id.value }) })
  })

  return {
    service,

    isAllowed,
    isBlacklisted,
    isCluster,
    isLoading,
    isDisabled,

    doEnable,
    doDisable,
    doRestart,
    doStart,
    doStop,
  }
}

// @vue/component
export default {
  name: 'base-service',
  props,
  setup
}
</script>
