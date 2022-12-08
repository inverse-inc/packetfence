<template>
  <b-dropdown ref="buttonRef"
    :disabled="isDisabled"
    :size="size"
    :text="service"
    no-flip
    variant="outline-primary"
    v-b-tooltip.hover.top.d300 :title="tooltip"
    v-bind="$attrs"
  >
    <template v-slot:button-content>
      <div class="d-inline px-1">
        <icon v-if="!Object.keys(servers).length" name="circle-notch" spin class="fa-overlap mr-1" />
        <template v-else v-for="(service, server) in servers">
          <icon v-if="service.status === 'loading'" :key="`icon-${server}`"
            name="circle-notch" spin class="text-primary fa-overlap mr-1" />
          <icon v-else-if="service.status === 'error'" :key="`icon-${server}`"
            name="exclamation-triangle" class="text-danger fa-overlap mr-1" />
          <icon v-else-if="service.isRestarting || service.isStarting || service.isStopping"  :key="`icon-${server}`"
            class="fa-overlap mr-1">
            <icon name="circle" class="text-white" />
            <icon v-if="service.isRestarting"
              name="redo" class="text-primary" scale="0.5" />
            <icon v-else-if="service.isStarting"
              name="play" class="text-primary" scale="0.5" />
            <icon v-else-if="service.isStopping"
              name="stop" class="text-primary" scale="0.5" />
          </icon>
          <icon v-else :key="`icon-${server}`"
            name="circle" :class="(service.alive && service.pid) ? 'text-success' : 'text-danger'" class="fa-overlap mr-1" />
        </template>
        {{ service }}
      </div>
    </template>

    <b-dropdown-group v-if="isAllowed && isCluster"
      :header="$i18n.t('CLUSTER')">
      <b-dropdown-item v-if="restart && cluster.hasAlive"
        @click="doRestartAll" @click.stop="onClick" :disabled="isLoading"><icon name="redo" class="mr-1" /> {{ $t('Restart All Sequentially') }}</b-dropdown-item>
      <b-dropdown-item v-if="start && cluster.hasDead"
        @click="doStartAll" @click.stop="onClick" :disabled="isLoading"><icon name="play" class="mr-1" /> {{ $t('Start All Sequentially') }}</b-dropdown-item>
      <b-dropdown-item v-if="stop && cluster.hasAlive"
        @click="doStopAll" @click.stop="onClick" :disabled="isLoading"><icon name="stop" class="mr-1" /> {{ $t('Stop All Sequentially') }}</b-dropdown-item>
    </b-dropdown-group>

    <template v-for="(service, server) in servers">
      <b-dropdown-divider v-if="isCluster" :key="`divider-${server}`" />
      <b-dropdown-group :key="`group-${server}`">
       <template v-slot:header>
         {{ server }}
        </template>
        <b-dropdown-form style="width: 400px;">
          <base-system-service :id="service.id" :server="server" v-bind="{ acl, restart, start, stop }" />
        </b-dropdown-form>
      </b-dropdown-group>
    </template>
  </b-dropdown>
</template>
<script>
import BaseSystemService from './BaseSystemService'

const components = {
  BaseSystemService
}

import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import { localeStrings } from '@/globals/pfLocales'

const props = {
  service: {
    type: String
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
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },
  disabled: {
    type: Boolean
  },
  acl: {
    type: String,
    default: 'SERVICES_READ'
  }
}

const setup = (props, context) => {

  const buttonRef = ref(null)

  const onClick = event => {
    event.stopPropagation()
    nextTick(() => {
      buttonRef.value.show() // keep open on click
    })
  }

  const {
    service,
    disabled,
    acl: _acl
  } = toRefs(props)

  const { root: { $store } = {}, emit } = context

  const isAllowed = computed(() => {
    if (_acl.value) {
      const [ verb, ...nouns ] = Array.prototype.slice.call(_acl.value.toLowerCase().split('_')).reverse()
      const noun = nouns.reverse().join('_')
      return verb && nouns.length > 0 && acl.$can(verb, noun)
    }
    return true
  })

  const servers = computed(() => {
    const { [service.value]: { servers = {} } = {} } = $store.getters['cluster/systemServicesByServer']
    return servers
  })
  watch(service, () => {
    if (isAllowed.value) {
      $store.dispatch('cluster/getSystemServiceCluster', service.value)
    }
  }, { immediate: true })

  const isCluster = computed(() => $store.getters['cluster/isCluster'])
  const isLoading = computed(() => $store.getters['cluster/isLoading'])
  const isDisabled = computed(() => disabled.value || !isAllowed.value || !Object.keys(servers.value).length)
  const cluster = computed(() => {
    const { [service.value]: cluster = {} } = $store.getters['cluster/systemServicesByServer']
    return cluster
  })

  const tooltip = computed(() => {
    switch (true) {
      case !isAllowed.value:
        return i18n.t('No permission, admin role {acl} required.', { acl: _acl.value })
        //break

      default:
        return undefined
    }
  })

  const doRestart = server => $store.dispatch('cluster/restartSystemService', { server, id: service.value }).then(() => {
    $store.dispatch('notification/info', { url: server, message: i18n.t(localeStrings.SERVICES_RESTARTED_SUCCESS, { services: `<code>${service.value}</code>` }) })
    emit('restart', { server, id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server, message: i18n.t(localeStrings.SERVICES_RESTARTED_ERROR, { services: `<code>${service.value}</code>` }) })
  })

  const doStart = server => $store.dispatch('cluster/startSystemService', { server, id: service.value }).then(() => {
    $store.dispatch('notification/info', { url: server, message: i18n.t(localeStrings.SERVICES_STARTED_SUCCESS, { services: `<code>${service.value}</code>` }) })
    emit('start', { server, id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server, message: i18n.t(localeStrings.SERVICES_STARTED_ERROR, { services: `<code>${service.value}</code>` }) })
  })

  const doStop = server => $store.dispatch('cluster/stopSystemService', { server, id: service.value }).then(() => {
    $store.dispatch('notification/info', { url: server, message: i18n.t(localeStrings.SERVICES_STOPPED_SUCCESS, { services: `<code>${service.value}</code>` }) })
    emit('stop', { server, id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server, message: i18n.t(localeStrings.SERVICES_STOPPED_ERROR, { services: `<code>${service.value}</code>` }) })
  })

  const doRestartAll = () => $store.dispatch('cluster/restartSystemServiceCluster', service.value).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_RESTARTED_SUCCESS, { services: `<code>${service.value}</code>` }) })
    emit('restart', { id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_RESTARTED_ERROR, { services: `<code>${service.value}</code>` }) })
  })

  const doStartAll = () => $store.dispatch('cluster/startSystemServiceCluster', service.value).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STARTED_SUCCESS, { services: `<code>${service.value}</code>` }) })
    emit('start', { id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STARTED_ERROR, { services: `<code>${service.value}</code>` }) })
  })

  const doStopAll = () => $store.dispatch('cluster/stopSystemServiceCluster', service.value).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STOPPED_SUCCESS, { services: `<code>${service.value}</code>` }) })
    emit('stop', { id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STOPPED_ERROR, { services: `<code>${service.value}</code>` }) })
  })

  return {
    servers,

    buttonRef,
    onClick,

    isAllowed,
    isCluster,
    isDisabled,
    isLoading,
    cluster,
    tooltip,

    doRestart,
    doRestartAll,
    doStart,
    doStartAll,
    doStop,
    doStopAll
  }
}

// @vue/component
export default {
  name: 'base-button-system-service',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
