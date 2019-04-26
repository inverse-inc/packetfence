<template>
  <div>
    <b-card no-body class="mt-3">
      <b-card-header>
        <h4 class="d-inline mb-0" v-t="'Protected Services'"></h4>
        <p class="mt-3 mb-0" v-t="'These services can not be managed since they are required in order for this page to function.'"></p>
      </b-card-header>
      <div class="card-body">
        <b-table
          :fields="fields"
          :items="protectedServices"
          :sort-by="sortBy"
          :sort-desc="sortDesc"
          :hover="protectedServices.length > 0"
          show-empty
          responsive
          fixed
          striped
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isLoading">{{ $t('No Services found') }}</pf-empty-table>
          </template>
          <template slot="enabled" slot-scope="service">
            <pf-form-range-toggle
              v-model="service.item.enabled"
              :values="{ checked: true, unchecked: false }"
              :icons="{ checked: 'check', unchecked: 'times' }"
              :disabled="![200, 'error'].includes(service.item.status) || !('enabled' in service.item)"
              @input="toggleEnabled(service.item, $event)"
              @click.stop.prevent
            >{{ (service.item.enabled === true) ? $t('Enabled') : $t('Disabled') }}</pf-form-range-toggle>
          </template>
          <template slot="alive" slot-scope="service">
            <pf-form-range-toggle
              v-model="service.item.alive"
              :values="{ checked: true, unchecked: false }"
              :icons="{ checked: 'lock', unchecked: 'lock' }"
              :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
              :disabled="true"
              @click.stop.prevent
            >{{ (service.item.alive === true) ? $t('Running') : $t('Stopped') }}</pf-form-range-toggle>
          </template>
          <template slot="pid" slot-scope="service">
            <icon v-if="![200, 'error'].includes(service.item.status)" name="circle-notch" spin></icon>
            <span v-else-if="service.item.alive">{{ service.item.pid }}</span>
          </template>
        </b-table>
      </div>
    </b-card>

    <b-card no-body class="mt-3">
      <b-card-header>
        <h4 class="d-inline mb-0" v-t="'Manageable Services'"></h4>
      </b-card-header>
      <div class="card-body">
        <b-row align-h="start" align-v="start" class="mb-3">
          <b-col cols="auto">
            <b-button variant="outline-danger" @click="stopAllServices($event)" class="mr-1" :disabled="isLoading">
              <span class="text-nowrap align-items-center"><icon :name="(isStopping) ? 'circle-notch' : 'square'" class="mr-2" :spin="isStopping"></icon> {{ $t('Stop All') }}</span>
            </b-button>
            <b-button variant="outline-success" @click="startAllServices($event)" class="mr-1" :disabled="isLoading">
              <span class="text-nowrap align-items-center"><icon :name="(isStarting) ? 'circle-notch' : 'play'" class="mr-2" :spin="isStarting"></icon> {{ $t('Start All') }}</span>
            </b-button>
            <b-button variant="outline-warning" @click="restartAllServices($event)" class="mr-1" :disabled="isLoading">
              <span class="text-nowrap align-items-center"><icon :name="(isRestarting) ? 'circle-notch' : 'sync'" class="mr-2" :spin="isRestarting"></icon> {{ $t('Restart All') }}</span>
            </b-button>
          </b-col>
        </b-row>
        <b-table
          :fields="fields"
          :items="manageableServices"
          :sort-by="sortBy"
          :sort-desc="sortDesc"
          :hover="manageableServices.length > 0"
          show-empty
          responsive
          fixed
          striped
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isLoading">{{ $t('No Services found') }}</pf-empty-table>
          </template>
          <template slot="name" slot-scope="service" class="align-items-center">
            <icon v-if="!service.item.alive && service.item.managed"
              name="exclamation-triangle" size="sm" class="text-danger mr-1" v-b-tooltip.hover.top.d300 :title="$t('Service {name} is required with this configuration.', { name: service.item.name})"></icon>
            <icon v-if="service.item.alive && !service.item.managed"
              name="exclamation-triangle" size="sm" class="text-success mr-1" v-b-tooltip.hover.top.d300 :title="$t('Service {name} is not required with this configuration.', { name: service.item.name})"></icon>
            {{ service.item.name }}
          </template>
          <template slot="enabled" slot-scope="service">
            <pf-form-range-toggle
              v-model="service.item.enabled"
              :values="{ checked: true, unchecked: false }"
              :icons="{ checked: 'check', unchecked: 'times' }"
              :disabled="![200, 'error'].includes(service.item.status) || !('enabled' in service.item)"
              @input="toggleEnabled(service.item, $event)"
              @click.stop.prevent
            >{{ (service.item.enabled === true) ? $t('Enabled') : $t('Disabled') }}</pf-form-range-toggle>
          </template>
          <template slot="alive" slot-scope="service" class="text-nowrap">
            <pf-form-range-toggle
              v-model="service.item.alive"
              :values="{ checked: true, unchecked: false }"
              :icons="{ checked: 'check', unchecked: 'times' }"
              :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
              :disabled="![200, 'error'].includes(service.item.status) || !('alive' in service.item)"
              class="d-inline"
              @input="toggleRunning(service.item, $event)"
              @click.stop.prevent
            >{{ (service.item.alive === true) ? $t('Running') : $t('Stopped') }}</pf-form-range-toggle>
          </template>
          <template slot="pid" slot-scope="service">
            <icon v-if="![200, 'error'].includes(service.item.status)" name="circle-notch" spin></icon>
            <span v-else-if="service.item.alive">{{ service.item.pid }}</span>
          </template>
        </b-table>
      </div>
    </b-card>
  </div>
</template>

<script>
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'

export default {
  name: 'Services',
  components: {
    pfEmptyTable,
    pfFormRangeToggle
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    blacklistedServices () {
      return this.$store.getters[`${this.storeName}/blacklistedServices`]
    },
    isLoading () {
      return this.$store.getters[`${this.storeName}/isServicesLoading`]
    },
    isStopping () {
      return this.$store.getters[`${this.storeName}/isServicesStopping`]
    },
    isStarting () {
      return this.$store.getters[`${this.storeName}/isServicesStarting`]
    },
    isRestarting () {
      return this.$store.getters[`${this.storeName}/isServicesRestarting`]
    },
    manageableServices () {
      return this.$store.state[this.storeName].services.filter(service => !(this.blacklistedServices.includes(service.name)))
    },
    protectedServices () {
      return this.$store.state[this.storeName].services.filter(service => this.blacklistedServices.includes(service.name))
    }
  },
  data () {
    return {
      sortBy: 'name',
      sortDesc: false,
      fields: [
        {
          key: 'name',
          label: this.$i18n.t('Service'),
          sortable: true,
          visible: true
        },
        {
          key: 'enabled',
          label: this.$i18n.t('Enabled'),
          sortable: true,
          visible: true
        },
        {
          key: 'alive',
          label: this.$i18n.t('Running'),
          sortable: true,
          visible: true
        },
        {
          key: 'pid',
          label: this.$i18n.t('PID'),
          sortable: true,
          visible: true
        }
      ]
    }
  },
  methods: {
    toggleEnabled (service, event) {
      switch (event) {
        case false:
          this.$store.dispatch(`${this.storeName}/disableService`, service.name).then(response => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('Service <code>{service}</code> disabled.', { service: service.name }) })
          })
          break
        case true:
          this.$store.dispatch(`${this.storeName}/enableService`, service.name).then(response => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('Service <code>{service}</code> enabled.', { service: service.name }) })
          })
          break
      }
    },
    toggleRunning (service, event) {
      switch (event) {
        case false:
          this.$store.dispatch(`${this.storeName}/stopService`, service.name).then(response => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('Service <code>{service}</code> stopped.', { service: service.name }) })
          })
          break
        case true:
          this.$store.dispatch(`${this.storeName}/startService`, service.name).then(response => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('Service <code>{service}</code> started.', { service: service.name }) })
          })
          break
      }
    },
    stopAllServices (event) {
      this.$store.dispatch('notification/info', { message: this.$i18n.t('Stopping all services.') })
      this.$store.dispatch(`${this.storeName}/stopAllServices`).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('All services stopped.') })
      })
    },
    startAllServices (event) {
      this.$store.dispatch('notification/info', { message: this.$i18n.t('Starting all services.') })
      this.$store.dispatch(`${this.storeName}/startAllServices`).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('All services started.') })
      })
    },
    restartAllServices (event) {
      this.$store.dispatch('notification/info', { message: this.$i18n.t('Restarting all services.') })
      this.$store.dispatch(`${this.storeName}/restartAllServices`).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('All services restarted.') })
      })
    },
    isBlacklisted (service) {
      return this.blacklistedServices.includes(service.name)
    }
  },
  created () {
    this.$store.dispatch(`${this.storeName}/getServices`)
  }
}
</script>
