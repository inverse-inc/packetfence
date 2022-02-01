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
            name="circle" :class="service.alive ? 'text-success' : 'text-danger'" class="fa-overlap mr-1" />
        </template>
        {{ service }}
      </div>
    </template>

    <b-dropdown-text v-if="isBlacklisted"
      class="small">
      {{ $t('This service must be managed from the command-line.') }}
    </b-dropdown-text>
    <b-dropdown-group v-else-if="isAllowed && Object.keys(servers).length"
      :header="$i18n.t('CLUSTER')">
      <b-dropdown-item v-if="enable && Object.keys(servers).filter(server => !servers[server].enabled).length"
        @click="doEnableAll" @click.stop="onClick" :disabled="isLoading"><icon name="toggle-on" class="mr-1" /> {{ $t('Enable All') }}</b-dropdown-item>
      <b-dropdown-item v-if="disable && Object.keys(servers).filter(server => servers[server].enabled).length"
        @click="doDisableAll" @click.stop="onClick" :disabled="isLoading"><icon name="toggle-off" class="mr-1" /> {{ $t('Disable All') }}</b-dropdown-item>
      <b-dropdown-item v-if="restart && Object.keys(servers).filter(server => servers[server].alive).length"
        @click="doRestartAll" @click.stop="onClick" :disabled="isLoading"><icon name="redo" class="mr-1" /> {{ $t('Restart All') }}</b-dropdown-item>
      <b-dropdown-item v-if="start && Object.keys(servers).filter(server => !servers[server].alive).length"
        @click="doStartAll" @click.stop="onClick" :disabled="isLoading"><icon name="play" class="mr-1" /> {{ $t('Start All') }}</b-dropdown-item>
      <b-dropdown-item v-if="stop && Object.keys(servers).filter(server => servers[server].alive).length"
        @click="doStopAll" @click.stop="onClick" :disabled="isLoading"><icon name="stop" class="mr-1" /> {{ $t('Stop All') }}</b-dropdown-item>
    </b-dropdown-group>

    <template v-for="(service, server) in servers">
      <b-dropdown-group :key="`group-${server}`">
       <template v-slot:header>
         {{ server }}
         <div v-if="!['loading', 'success', 'error'].includes(service.status)"
          class="d-inline float-right">
            <icon name="circle-notch" spin class="mr-1" />
            <span v-if="service.status === 'disabling'">{{ $i18n.t('Disabling') }}...</span>
            <span v-if="service.status === 'enabling'">{{ $i18n.t('Enabling') }}...</span>
            <span v-if="service.status === 'restarting'">{{ $i18n.t('Restarting') }}...</span>
            <span v-if="service.status === 'starting'">{{ $i18n.t('Starting') }}...</span>
            <span v-if="service.status === 'stopping'">{{ $i18n.t('Stopping') }}...</span>
          </div>
        </template>
        <b-dropdown-form style="width: 400px;">
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
              <b-button v-if="enable && !service.enabled"
                @click="doEnable(server)" @click.stop="onClick" :disabled="isLoading" variant="link" size="sm" class="text-secondary mr-1">
                <icon name="toggle-on" class="mr-1" /> {{ $t('Enable') }}
              </b-button>
              <b-button v-if="disable && service.enabled"
                @click="doDisable(server)" @click.stop="onClick" :disabled="isLoading" variant="link" size="sm" class="text-secondary mr-1">
                <icon name="toggle-off" class="mr-1" /> {{ $t('Disable') }}
              </b-button>
              <b-button v-if="restart && service.alive"
                @click="doRestart(server)" @click.stop="onClick" :disabled="isLoading" variant="link" size="sm" class="text-secondary mr-1">
                <icon name="redo" class="mr-1" /> {{ $t('Restart') }}
              </b-button>
              <b-button v-if="start && !service.alive"
                @click="doStart(server)" @click.stop="onClick" :disabled="isLoading" variant="link" size="sm" class="text-secondary mr-1">
                <icon name="play" class="mr-1" /> {{ $t('Start') }}
              </b-button>
              <b-button v-if="stop && service.alive"
                @click="doStop(server)" @click.stop="onClick" :disabled="isLoading" variant="link" size="sm" class="text-secondary mr-1">
                <icon name="stop" class="mr-1" /> {{ $t('Stop') }}
              </b-button>
            </b-col>
          </b-row>
        </b-dropdown-form>
        <b-dropdown-form v-if="service.message && ['success', 'error'].includes(service.status)"
          class="small mb-0" :class="(service.status === 'error') ? 'text-danger' : 'text-secondary'">
          {{ service.message }}
        </b-dropdown-form>
      </b-dropdown-group>
      <b-dropdown-divider :key="`divider-${server}`" />
    </template>
  </b-dropdown>

</template>
<script>
import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import { blacklistedServices } from '@/store/modules/services'
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

  const servers = computed(() => $store.getters['cluster/servicesByServer'][service.value] || {})
  watch(service, () => {
    if (isAllowed.value) {
      $store.dispatch('cluster/getServiceCluster', service.value)
    }
  }, { immediate: true })

  const isBlacklisted = computed(() => !!blacklistedServices.find(bls => bls === service.value))
  const isLoading = computed(() => $store.getters['cluster/isLoading'])
  const isDisabled = computed(() => disabled.value || !isAllowed.value || !Object.keys(servers.value).length)

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
    $store.dispatch('notification/info', { url: server, message: i18n.t('Service <code>{service}</code> killed.', { service: service.value }) })
    emit('stop', { server, id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server, message: i18n.t('Failed to kill service <code>{service}</code>.  See the server error logs for more information.s', { service: service.value }) })
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
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t('Service <code>{service}</code> killed.', { service: service.value }) })
    emit('stop', { id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t('Failed to kill service <code>{service}</code>.  See the server error logs for more information.s', { service: service.value }) })
  })

  return {
    servers,

    buttonRef,
    onClick,

    isAllowed,
    isBlacklisted,
    isDisabled,
    isLoading,
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
  props,
  setup
}
</script>
