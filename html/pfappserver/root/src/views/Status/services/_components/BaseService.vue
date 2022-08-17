<template>
  <b-overlay :show="service.status && !['success', 'error'].includes(service.status)" variant="white">
    <b-container fluid class="px-0">
      <b-row class="row-nowrap mx-0" align-v="center">
        <b-col cols="7">
          <b-row class="row-nowrap py-1" cols="2"
            v-b-tooltip.hover.left.d300 :title="$t('PID: {pid}', service)"
          >
            <b-col cols="6" class="text-nowrap">{{ $i18n.t('Alive') }}</b-col>
            <b-col cols="auto" class="text-right ml-auto"><icon :class="(service.alive && service.pid) ? 'text-success' : 'text-danger'" name="circle"/></b-col>
          </b-row>
          <b-row class="row-nowrap py-1" cols="2">
            <b-col cols="6" class="text-nowrap">{{ $i18n.t('Enabled') }}</b-col>
            <b-col cols="auto" class="text-right ml-auto"><icon :class="(service.enabled) ? 'text-success' : 'text-danger'" name="circle"/></b-col>
          </b-row>
        </b-col>
        <b-col cols="5" class="text-wrap" v-if="isAllowed">
          <template>
            <b-button v-if="enable && !service.enabled"
              @click="doEnable(server)" :disabled="isLoading" variant="link" size="sm" class="text-nowrap text-secondary mr-1">
              <icon name="toggle-on" class="mr-1" /> {{ $i18n.t('Enable') }}
            </b-button>
            <b-button v-if="disable && service.enabled"
              @click="doDisable(server)" :disabled="isLoading" variant="link" size="sm" class="text-nowrap text-secondary mr-1">
              <icon name="toggle-off" class="mr-1" /> {{ $i18n.t('Disable') }}
            </b-button>
            <b-button v-if="restart && service.alive && service.pid && !isProtected "
              @click="doRestart(server)" :disabled="isLoading" variant="link" size="sm" class="text-nowrap text-secondary mr-1">
              <icon name="redo" class="mr-1" /> {{ $i18n.t('Restart') }}
            </b-button>
            <b-button v-if="start && !(service.alive && service.pid) && !isProtected "
              @click="doStart(server)" :disabled="isLoading" variant="link" size="sm" class="text-nowrap text-secondary mr-1">
              <icon name="play" class="mr-1" /> {{ $i18n.t('Start') }}
            </b-button>
            <b-button v-if="stop && service.alive && service.pid && !isProtected "
              @click="doStop(server)" :disabled="isLoading" variant="link" size="sm" class="text-nowrap text-secondary mr-1">
              <icon name="stop" class="mr-1" /> {{ $i18n.t('Stop') }}
            </b-button>
          </template>
        </b-col>
      </b-row>
      <b-row v-if="isProtected"
        class="mt-2 mx-0">
        <b-col cols="auto" class="small text-secondary text-wrap">
          {{ $i18n.t('This service can not be managed since it is required for this page to function.') }}
        </b-col>
      </b-row>
      <b-row v-if="!service.alive && service.managed"
        class="mt-2 mx-0">
        <b-col cols="auto" class="small text-danger text-wrap">
          {{ $i18n.t('Service {name} is required with this configuration.', { name: service.id }) }}
        </b-col>
      </b-row>
      <b-row v-if="service.alive && !service.managed"
        class="mt-2 mx-0">
        <b-col cols="auto" class="small text-danger text-wrap">
          {{ $i18n.t('Service {name} is not required with this configuration.', { name: service.id }) }}
        </b-col>
      </b-row>
      <b-row v-if="service.message"
        class="mt-2 mx-0">
        <b-col cols="auto" class="small text-danger text-wrap">
          {{ service.message }}
        </b-col>
      </b-row>
    </b-container>
    <template v-slot:overlay v-if="service.status && service.status !== 'loading'">
      <b-row class="justify-content-md-center">
        <b-col cols="auto">
          <b-media class="text-gray text-uppercase font-weight-bold">
            <template v-slot:aside><icon name="circle-notch" spin scale="1.5" /></template>
            <p v-if="service.status === 'disabling'" class="mb-0">{{ $i18n.t('Disabling') }}</p>
            <p v-if="service.status === 'enabling'" class="mb-0">{{ $i18n.t('Enabling') }}</p>
            <p v-if="service.status === 'restarting'" class="mb-0">{{ $i18n.t('Restarting') }}</p>
            <p v-if="service.status === 'starting'" class="mb-0">{{ $i18n.t('Starting') }}</p>
            <p v-if="service.status === 'stopping'" class="mb-0">{{ $i18n.t('Stopping') }}</p>
          </b-media>
        </b-col>
      </b-row>
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
  enable: {
    type: Boolean
  },
  disable: {
    type: Boolean
  },
  restart: {
    type: Boolean
  },
  start: {
    type: Boolean
  },
  stop: {
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
import { protectedServices } from '@/store/modules/cluster'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import { localeStrings } from '../config'

const setup = (props, context) => {

  const {
    id,
    server,
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
    if (id.value && server.value && isAllowed.value && !lazy.value) {
      $store.dispatch('system/getHostname').then(() => {
        $store.dispatch('cluster/getService', { server: server.value, id: id.value })
      })
    }
  }, { immediate: true })
  const service = computed(() => $store.state.cluster.servers[server.value].services[id.value] || {})
  const isProtected = computed(() => !!protectedServices.find(listed => listed === id.value))
  const isCluster = computed(() => $store.getters['cluster/isCluster'])
  const isLoading = computed(() => $store.getters['cluster/isLoading'])

  const doEnable = () => $store.dispatch('cluster/enableService', { server: server.value, id: id.value }).then(() => {
    $store.dispatch('notification/info', { url: server.value, message: i18n.t(localeStrings.SERVICES_ENABLED_SUCCESS, { services: `<code>${id.value}</code>` }) })
    emit('enable', { server, id: id.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server.value, message: i18n.t(localeStrings.SERVICES_ENABLED_ERROR, { services: `<code>${id.value}</code>` }) })
  })

  const doDisable = () => $store.dispatch('cluster/disableService', { server: server.value, id: id.value }).then(() => {
    $store.dispatch('notification/info', { url: server.value, message: i18n.t(localeStrings.SERVICES_DISABLED_SUCCESS, { services: `<code>${id.value}</code>` }) })
    emit('disable', { server, id: id.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server.value, message: i18n.t(localeStrings.SERVICES_DISABLED_ERROR, { services: `<code>${id.value}</code>` }) })
  })

  const doRestart = () => $store.dispatch('cluster/restartService', { server: server.value, id: id.value }).then(() => {
    $store.dispatch('notification/info', { url: server.value, message: i18n.t(localeStrings.SERVICES_RESTARTED_SUCCESS, { services: `<code>${id.value}</code>` }) })
    emit('restart', { server, id: id.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server.value, message: i18n.t(localeStrings.SERVICES_RESTARTED_ERROR, { services: `<code>${id.value}</code>` }) })
  })

  const doStart = () => $store.dispatch('cluster/startService', { server: server.value, id: id.value }).then(() => {
    $store.dispatch('notification/info', { url: server.value, message: i18n.t(localeStrings.SERVICES_STARTED_SUCCESS, { services: `<code>${id.value}</code>` }) })
    emit('start', { server, id: id.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server.value, message: i18n.t(localeStrings.SERVICES_STARTED_ERROR, { services: `<code>${id.value}</code>` }) })
  })

  const doStop = () => $store.dispatch('cluster/stopService', { server: server.value, id: id.value }).then(() => {
    $store.dispatch('notification/info', { url: server.value, message: i18n.t(localeStrings.SERVICES_STOPPED_SUCCESS, { services: `<code>${id.value}</code>` }) })
    emit('stop', { server, id: id.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server.value, message: i18n.t(localeStrings.SERVICES_STOPPED_ERROR, { services: `<code>${id.value}</code>` }) })
  })

  return {
    service,

    isAllowed,
    isProtected,
    isCluster,
    isLoading,

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
