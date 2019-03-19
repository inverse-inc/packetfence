<template>
  <b-dropdown ref="serviceButton"
    :style="{ minWidth: btnWidth }"
    :text="service"
    :variant="buttonVariant"
    v-bind="$attrs"
    v-on="forwardListeners"
  >
    <template slot="button-content">
      <icon :name="buttonIcon.name" :spin="buttonIcon.spin" class="mr-1"></icon>
      {{ buttonText }}
    </template>
    <b-dropdown-form>
      <b-row class="row-nowrap">
        <b-col>{{ $t('Alive') }}</b-col>
        <b-col cols="auto">
          <b-badge v-if="serviceStatus.alive && serviceStatus.pid" pill variant="success">{{ $t(serviceStatus.pid) }}</b-badge>
          <icon v-else class="text-danger" name="circle"></icon>
        </b-col>
      </b-row>
      <b-row class="row-nowrap">
        <b-col>{{ $t('Enabled') }}</b-col>
        <b-col cols="auto"><icon :class="(serviceStatus.enabled) ? 'text-success' : 'text-danger'" name="circle"></icon></b-col>
      </b-row>
      <b-row class="row-nowrap">
        <b-col>{{ $t('Managed') }}</b-col>
        <b-col cols="auto"><icon :class="(serviceStatus.managed) ? 'text-success' : 'text-danger'" name="circle"></icon></b-col>
      </b-row>
    </b-dropdown-form>
    <b-dropdown-divider v-if="!isLoading"></b-dropdown-divider>
    <b-dropdown-item v-if="canEnable" @click="doEnable"><icon name="toggle-on" class="mr-1" @click.stop="onClick"></icon> {{ $t('Enable') }}</b-dropdown-item>
    <b-dropdown-item v-if="canDisable" @click="doDisable"><icon name="toggle-off" class="mr-1" @click.stop="onClick"></icon> {{ $t('Disable') }}</b-dropdown-item>
    <b-dropdown-item v-if="canRestart" @click="doRestart"><icon name="circle-notch" class="mr-1" @click.stop="onClick"></icon> {{ $t('Restart') }}</b-dropdown-item>
    <b-dropdown-item v-if="canStart" @click="doStart"><icon name="play" class="mr-1" @click.stop="onClick"></icon> {{ $t('Start') }}</b-dropdown-item>
    <b-dropdown-item v-if="canStop" @click="doStop"><icon name="stop" class="mr-1" @click.stop="onClick"></icon> {{ $t('Stop') }}</b-dropdown-item>
  </b-dropdown>
</template>

<script>
export default {
  name: 'pf-button-service',
  props: {
    service: {
      type: String,
      default: null
    },
    enable: {
      type: Boolean,
      default: false
    },
    disable: {
      type: Boolean,
      default: false
    },
    restart: {
      type: Boolean,
      default: false
    },
    start: {
      type: Boolean,
      default: false
    },
    stop: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      btnWidth: 0,
      serviceStatus: {}
    }
  },
  computed: {
    canEnable () {
      return (this.enable && !this.serviceStatus.enabled && !this.isLoading)
    },
    canDisable () {
      return (this.disable && this.serviceStatus.enabled && !this.isLoading)
    },
    canRestart () {
      return (this.restart && this.serviceStatus.alive && !this.isLoading)
    },
    canStart () {
      return (this.start && !this.serviceStatus.alive && !this.isLoading)
    },
    canStop () {
      return (this.stop && this.serviceStatus.alive && !this.isLoading)
    },
    isLoading () {
      return (!('status' in this.serviceStatus) || !['success', 'error'].includes(this.serviceStatus.status))
    },
    isEnabling () {
      return ('status' in this.serviceStatus && this.serviceStatus.status === 'enabling')
    },
    isDisabling () {
      return ('status' in this.serviceStatus && this.serviceStatus.status === 'disabling')
    },
    isRestarting () {
      return ('status' in this.serviceStatus && this.serviceStatus.status === 'restarting')
    },
    isStarting () {
      return ('status' in this.serviceStatus && this.serviceStatus.status === 'starting')
    },
    isStopping () {
      return ('status' in this.serviceStatus && this.serviceStatus.status === 'stopping')
    },
    isRunning () {
      return ('alive' in this.serviceStatus && this.serviceStatus.alive)
    },
    isError () {
      return ('status' in this.serviceStatus && this.serviceStatus.status === 'error')
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    },
    buttonVariant () {
      switch (true) {
        case this.isLoading:
          return 'outline-warning'
          // break
        case this.isRunning:
          return 'outline-success'
          // break
        default:
          return 'outline-danger'
          // break
      }
    },
    buttonIcon () {
      switch (true) {
        case this.isEnabling:
        case this.isDisabling:
        case this.isRestarting:
        case this.isStarting:
        case this.isStopping:
        case this.isLoading:
          return { name: 'circle-notch', spin: true }
          // break
        case this.isError:
          return { name: 'exclamation-circle', spin: false }
          // break
        default:
          return { name: 'circle', spin: false }
          // break
      }
    },
    buttonText () {
      switch (true) {
        case this.isEnabling:
          return this.$i18n.t('Enabling {service}', { service: this.service })
          // break
        case this.isDisabling:
          return this.$i18n.t('Disabling {service}', { service: this.service })
          // break
        case this.isRestarting:
          return this.$i18n.t('Restarting {service}', { service: this.service })
          // break
        case this.isStarting:
          return this.$i18n.t('Starting {service}', { service: this.service })
          // break
        case this.isStopping:
          return this.$i18n.t('Stopping {service}', { service: this.service })
          // break
        default:
          return this.service
          // break
      }
    }
  },
  methods: {
    status () {
      this.$store.dispatch('$_services/getService', this.service).then(response => {
        this.$set(this, 'serviceStatus', response)
      })
    },
    doEnable () {
      this.$store.dispatch('$_services/enableService', this.service).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Enabled {service}', { service: this.service }) })
      }).catch(() => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Failed to enable {service}. See the server error logs for more information.', { service: this.service }) })
      })
    },
    doDisable () {
      this.$store.dispatch('$_services/disableService', this.service).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Disabled {service}', { service: this.service }) })
      }).catch(() => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Failed to disable {service}. See the server error logs for more information.', { service: this.service }) })
      })
    },
    doRestart () {
      this.$store.dispatch('$_services/restartService', this.service).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Restarted {service}', { service: this.service }) })
      }).catch(() => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Failed to restart {service}.  See the server error logs for more information.', { service: this.service }) })
      })
    },
    doStart () {
      this.$store.dispatch('$_services/startService', this.service).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Started {service}', { service: this.service }) })
      }).catch(() => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Failed to start {service}.  See the server error logs for more information.', { service: this.service }) })
      })
    },
    doStop () {
      this.$store.dispatch('$_services/stopService', this.service).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Killed {service}', { service: this.service }) })
      }).catch(() => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Failed to kill {service}.  See the server error logs for more information.s', { service: this.service }) })
      })
    },
    onClick (event) {
      event.stopPropagation()
      this.$nextTick(() => {
        this.$refs.serviceButton.show() // keep open on click
      })
    }
  },
  created () {
    this.status()
  },
  watch: {
    isLoading: {
      handler: function (newValue) {
        if (newValue) {
          this.btnWidth = (this.$refs.serviceButton.clientWidth + 2) + 'px'
        }
      }
    }
  }
}
</script>
