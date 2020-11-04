<template>
  <b-dropdown ref="buttonRef"
    :disabled="disabled"
    :size="size"
    :text="service"
    :variant="buttonVariant"
    v-b-tooltip.hover.top.d300 :title="tooltip"
    v-bind="$attrs"
  >
    <template v-slot:button-content>
      <icon :name="buttonIcon.name" :spin="buttonIcon.spin" class="mr-1"></icon>
      {{ buttonText }}
    </template>
    <b-dropdown-form v-if="!hideDetails">
      <b-row class="row-nowrap">
        <b-col>{{ $t('Alive') }}</b-col>
        <b-col cols="auto">
          <b-badge v-if="status.alive && status.pid" pill variant="success">{{ status.pid }}</b-badge>
          <icon v-else class="text-danger" name="circle"></icon>
        </b-col>
      </b-row>
      <b-row class="row-nowrap">
        <b-col>{{ $t('Enabled') }}</b-col>
        <b-col cols="auto"><icon :class="(status.enabled) ? 'text-success' : 'text-danger'" name="circle"></icon></b-col>
      </b-row>
      <b-row class="row-nowrap">
        <b-col>{{ $t('Managed') }}</b-col>
        <b-col cols="auto"><icon :class="(status.managed) ? 'text-success' : 'text-danger'" name="circle"></icon></b-col>
      </b-row>
    </b-dropdown-form>
    <b-dropdown-divider v-if="!isLoading && !hideDetails"></b-dropdown-divider>
    <b-dropdown-item v-if="canEnable" @click="doEnable"><icon name="toggle-on" class="mr-1" @click.stop="onClick"></icon> {{ $t('Enable') }}</b-dropdown-item>
    <b-dropdown-item v-if="canDisable" @click="doDisable"><icon name="toggle-off" class="mr-1" @click.stop="onClick"></icon> {{ $t('Disable') }}</b-dropdown-item>
    <b-dropdown-item v-if="canRestart" @click="doRestart"><icon name="redo" class="mr-1" @click.stop="onClick"></icon> {{ $t('Restart') }}</b-dropdown-item>
    <b-dropdown-item v-if="canStart" @click="doStart"><icon name="play" class="mr-1" @click.stop="onClick"></icon> {{ $t('Start') }}</b-dropdown-item>
    <b-dropdown-item v-if="canStop" @click="doStop"><icon name="stop" class="mr-1" @click.stop="onClick"></icon> {{ $t('Stop') }}</b-dropdown-item>
  </b-dropdown>
</template>
<script>
import { computed, nextTick, onMounted, ref, toRefs } from '@vue/composition-api'
import { blacklistedServices } from '@/store/modules/services'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'

const props = {
  service: {
    type: String
  },
  hideDetails: {
    type: Boolean
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
    enable,
    disable,
    restart,
    start,
    stop
  } = toRefs(props)

  const { root: { $store } = {}, emit } = context

  const status = computed(() => {
    const { state: { services: { cache: { [service.value]: _service } = {} } = {} } = {} } = $store
    return _service || { status: 'loading' }
  })

  const isAllowed = computed(() => acl.$can('read', 'services'))
  const isError = computed(() => status.value.status === 'error' || blacklistedServices.find(bls => bls === service.value))
  const isLoading = computed(() => {
    if (status.value.status)
      return !['success', 'error'].includes(status.value.status)
    return true
  })
  const disabled = computed(() => isError.value || !isAllowed.value)

  const tooltip = computed(() => {
    switch (true) {
      case !isAllowed.value:
        return i18n.t('No permission, admin role SERVICES_READ required.')
        //break

      default:
        return
    }
  })

  const canEnable = computed(() => enable.value && !status.value.enabled && !isLoading.value)
  const canDisable = computed(() => disable.value && status.value.enabled && !isLoading.value)
  const canRestart = computed(() => restart.value && status.value.alive && !isLoading.value)
  const canStart = computed(() => start.value && !status.value.alive && !isLoading.value)
  const canStop = computed(() => stop.value && status.value.alive && !isLoading.value)

  const buttonVariant = computed(() => {
    switch (true) {
      case isLoading.value:
        return 'outline-secondary'
        // break

      case status.value.alive:
        return 'outline-success'
        // break

      default:
        return 'outline-danger'
        // break
    }
  })

  const buttonIcon = computed(() => {
    switch (true) {
      case !isAllowed.value:
        return { name: 'exclamation-circle', spin: false }
        //break

      case ['enabling', 'disabling', 'restarting', 'starting', 'stopping'].includes(status.value.status):
      case isLoading.value:
        return { name: 'circle-notch', spin: true }
        // break

      case isError.value:
        return { name: 'exclamation-circle', spin: false }
        // break

      default:
        return { name: 'circle', spin: false }
        // break
    }
  })

  const buttonText = computed(() => {
    const params = { service: service.value }
    switch (true) {
      case status.value.status === 'enabling':
        return i18n.t('Enabling {service}', params)
        // break

      case status.value.status === 'disabling':
        return i18n.t('Disabling {service}', params)
        // break

      case status.value.status === 'restarting':
        return i18n.t('Restarting {service}', params)
        // break

      case status.value.status === 'starting':
        return i18n.t('Starting {service}', params)
        // break

      case status.value.status === 'stopping':
        return i18n.t('Stopping {service}', params)
        // break

      default:
        return service.value
        // break
    }
  })

  const doEnable = () => $store.dispatch('services/enableService', service.value).then(() => {
    $store.dispatch('notification/info', { message: i18n.t('Service <code>{service}</code> enabled.', { service: service.value }) })
    emit('enable', service.value)
  }).catch(() => {
    $store.dispatch('notification/danger', { message: i18n.t('Failed to enable service <code>{service}</code>. See the server error logs for more information.', { service: service.value }) })
  })

  const doDisable = () => $store.dispatch('services/disableService', service.value).then(() => {
    $store.dispatch('notification/info', { message: i18n.t('Service <code>{service}</code> disabled.', { service: service.value }) })
    emit('disable', service.value)
  }).catch(() => {
    $store.dispatch('notification/danger', { message: i18n.t('Failed to disable service <code>{service}</code>. See the server error logs for more information.', { service: service.value }) })
  })

  const doRestart = () => $store.dispatch('services/restartService', service.value).then(() => {
    $store.dispatch('notification/info', { message: i18n.t('Service <code>{service}</code> restarted.', { service: service.value }) })
    emit('restart', service.value)
  }).catch(() => {
    $store.dispatch('notification/danger', { message: i18n.t('Failed to restart service <code>{service}</code>.  See the server error logs for more information.', { service: service.value }) })
  })

  const doStart = () => $store.dispatch('services/startService', service.value).then(() => {
    $store.dispatch('notification/info', { message: i18n.t('Service <code>{service}</code> started.', { service: service.value }) })
    emit('start', service.value)
  }).catch(() => {
    $store.dispatch('notification/danger', { message: i18n.t('Failed to start service <code>{service}</code>.  See the server error logs for more information.', { service: service.value }) })
  })

  const doStop = () => $store.dispatch('services/stopService', service.value).then(() => {
    $store.dispatch('notification/info', { message: i18n.t('Service <code>{service}</code> killed.', { service: service.value }) })
    emit('stop', service.value)
  }).catch(() => {
    $store.dispatch('notification/danger', { message: i18n.t('Failed to kill service <code>{service}</code>.  See the server error logs for more information.s', { service: service.value }) })
  })

  onMounted(() => {
    if (isAllowed.value)
      $store.dispatch('services/getService', service.value)
  })

  return {
    buttonRef,
    onClick,

    status,
    isAllowed,
    isError,
    isLoading,
    disabled,
    tooltip,
    buttonVariant,
    buttonIcon,
    buttonText,

    canEnable,
    canDisable,
    canRestart,
    canStart,
    canStop,

    doEnable,
    doDisable,
    doRestart,
    doStart,
    doStop
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
