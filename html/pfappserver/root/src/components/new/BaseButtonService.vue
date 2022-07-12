<template>
  <b-dropdown ref="buttonRef"
    :disabled="isDisabled"
    :size="size"
    :text="service"
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
          <icon v-else :key="`icon-${server}`"
            name="circle" :class="(service.alive && service.pid) ? 'text-success' : 'text-danger'" class="fa-overlap mr-1" />
        </template>
        {{ service }}
      </div>
    </template>

    <b-dropdown-group v-if="isAllowed && isCluster"
      :header="$i18n.t('CLUSTER')">
      <b-dropdown-item v-if="enable && cluster.hasDisabled"
        @click="doEnableAll" @click.stop="onClick" :disabled="isLoading"><icon name="toggle-on" class="mr-1" /> {{ $t('Enable All') }}</b-dropdown-item>
      <b-dropdown-item v-if="disable && cluster.hasEnabled"
        @click="doDisableAll" @click.stop="onClick" :disabled="isLoading"><icon name="toggle-off" class="mr-1" /> {{ $t('Disable All') }}</b-dropdown-item>
      <b-dropdown-item v-if="restart && cluster.hasAlive"
        @click="doRestartAll" @click.stop="onClick" :disabled="isLoading"><icon name="redo" class="mr-1" /> {{ $t('Restart All') }}</b-dropdown-item>
      <b-dropdown-item v-if="start && cluster.hasDead"
        @click="doStartAll" @click.stop="onClick" :disabled="isLoading"><icon name="play" class="mr-1" /> {{ $t('Start All') }}</b-dropdown-item>
      <b-dropdown-item v-if="stop && cluster.hasAlive"
        @click="doStopAll" @click.stop="onClick" :disabled="isLoading"><icon name="stop" class="mr-1" /> {{ $t('Stop All') }}</b-dropdown-item>
    </b-dropdown-group>

    <template v-for="(service, server) in servers">
      <b-dropdown-divider v-if="isCluster" :key="`divider-${server}`" />
      <b-dropdown-group :key="`group-${server}`">
       <template v-slot:header>
         {{ server }}
        </template>
        <b-dropdown-form style="width: 400px;">
          <base-service :id="service.id" :server="server" v-bind="{ enable, disable, restart, start, stop }" />
        </b-dropdown-form>
      </b-dropdown-group>
    </template>
  </b-dropdown>

</template>
<script>
import BaseService from '@/views/Status/services/_components/BaseService'

const components = {
  BaseService
}

import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'

const props = {
  service: {
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
    const { [service.value]: { servers = {} } = {} } = $store.getters['cluster/servicesByServer']
    return servers
  })
  watch(service, () => {
    if (isAllowed.value) {
      $store.dispatch('cluster/getServiceCluster', service.value)
    }
  }, { immediate: true })

  const isCluster = computed(() => $store.getters['cluster/isCluster'])
  const isLoading = computed(() => $store.getters['cluster/isLoading'])
  const isDisabled = computed(() => disabled.value || !isAllowed.value || !Object.keys(servers.value).length)
  const cluster = computed(() => {
    const { [service.value]: cluster = {} } = $store.getters['cluster/servicesByServer']
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

  const doEnable = server => $store.dispatch('cluster/enableService', { server, id: service.value }).then(() => {
    $store.dispatch('notification/info', { url: server, message: i18n.t('Service <code>{service}</code> enabled.', { service: service.value }) })
    emit('enable', { server, id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server, message: i18n.t('Failed to enable service <code>{service}</code>. See the server error logs for more information.', { service: service.value }) })
  })

  const doDisable = server => $store.dispatch('cluster/disableService', { server, id: service.value }).then(() => {
    $store.dispatch('notification/info', { url: server, message: i18n.t('Service <code>{service}</code> disabled.', { service: service.value }) })
    emit('disable', { server, id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server, message: i18n.t('Failed to disable service <code>{service}</code>. See the server error logs for more information.', { service: service.value }) })
  })

  const doRestart = server => $store.dispatch('cluster/restartService', { server, id: service.value }).then(() => {
    $store.dispatch('notification/info', { url: server, message: i18n.t('Service <code>{service}</code> restarted.', { service: service.value }) })
    emit('restart', { server, id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server, message: i18n.t('Failed to restart service <code>{service}</code>.  See the server error logs for more information.', { service: service.value }) })
  })

  const doStart = server => $store.dispatch('cluster/startService', { server, id: service.value }).then(() => {
    $store.dispatch('notification/info', { url: server, message: i18n.t('Service <code>{service}</code> started.', { service: service.value }) })
    emit('start', { server, id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server, message: i18n.t('Failed to start service <code>{service}</code>.  See the server error logs for more information.', { service: service.value }) })
  })

  const doStop = server => $store.dispatch('cluster/stopService', { server, id: service.value }).then(() => {
    $store.dispatch('notification/info', { url: server, message: i18n.t('Service <code>{service}</code> stopped.', { service: service.value }) })
    emit('stop', { server, id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server, message: i18n.t('Failed to stop service <code>{service}</code>.  See the server error logs for more information.s', { service: service.value }) })
  })

  const doEnableAll = () => $store.dispatch('cluster/enableServiceCluster', service.value).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t('Service <code>{service}</code> enabled.', { service: service.value }) })
    emit('enable', { id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t('Failed to enable service <code>{service}</code>. See the server error logs for more information.', { service: service.value }) })
  })

  const doDisableAll = () => $store.dispatch('cluster/disableServiceCluster', service.value).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t('Service <code>{service}</code> disabled.', { service: service.value }) })
    emit('disable', { id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t('Failed to disable service <code>{service}</code>. See the server error logs for more information.', { service: service.value }) })
  })

  const doRestartAll = () => $store.dispatch('cluster/restartServiceCluster', service.value).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t('Service <code>{service}</code> restarted.', { service: service.value }) })
    emit('restart', { id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t('Failed to restart service <code>{service}</code>.  See the server error logs for more information.', { service: service.value }) })
  })

  const doStartAll = () => $store.dispatch('cluster/startServiceCluster', service.value).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t('Service <code>{service}</code> started.', { service: service.value }) })
    emit('start', { id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t('Failed to start service <code>{service}</code>.  See the server error logs for more information.', { service: service.value }) })
  })

  const doStopAll = () => $store.dispatch('cluster/stopServiceCluster', service.value).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t('Service <code>{service}</code> stopped.', { service: service.value }) })
    emit('stop', { id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t('Failed to stop service <code>{service}</code>.  See the server error logs for more information.s', { service: service.value }) })
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

    doEnable,
    doEnableAll,
    doDisable,
    doDisableAll,
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
  name: 'base-button-service',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
