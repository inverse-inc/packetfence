<template>
  <div>
    <b-card no-body>
      <b-card-header>
        <h4 class="d-inline mb-0" v-t="'Services'"></h4>
        <p class="mt-3 mb-0" v-t="'...'"></p>
      </b-card-header>
      <div class="card-body">
        <b-table
          :fields="serviceFields"
          :items="serviceItems"
          :sort-by="'service'"
          :sort-desc="false"
          show-empty
          responsive
          fixed
          sort-icon-left
          striped
        >
          <template v-slot:empty>
            <base-table-empty :is-loading="isLoading">{{ $t('No Services found') }}</base-table-empty>
          </template>
          <template v-slot:cell(service)="{ value }">
            {{ value }}
          </template>
          <template v-slot:cell(actions)="{ item: { service, canDisable, canEnable, canRestart, canStart, canStop } }">
            <b-button v-if="canEnable"
              class="m-1" variant="outline-primary" @click="doEnableAll" :disabled="isLoading"><icon name="toggle-on" class="mr-1" /> {{ $t('Enable All') }}</b-button>
            <b-button v-if="canDisable"
              class="m-1" variant="outline-primary" @click="doDisableAll" :disabled="isLoading"><icon name="toggle-off" class="mr-1" /> {{ $t('Disable All') }}</b-button>
            <b-button v-if="canRestart"
              class="m-1" variant="outline-primary" @click="doRestartAll" :disabled="isLoading"><icon name="redo" class="mr-1" /> {{ $t('Restart All') }}</b-button>
            <b-button v-if="canStart"
              class="m-1" variant="outline-primary" @click="doStartAll" :disabled="isLoading"><icon name="play" class="mr-1" /> {{ $t('Start All') }}</b-button>
            <b-button v-if="canStop"
              class="m-1" variant="outline-primary" @click="doStopAll" :disabled="isLoading"><icon name="stop" class="mr-1" /> {{ $t('Stop All') }}</b-button>
          </template>
          <template v-slot:cell()="{ item, value }">
            <base-service :id="item.service" :server="value.server" class="py-3" lazy />
          </template>
        </b-table>
      </div>
    </b-card>




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
          sort-icon-left
          striped
        >
          <template v-slot:empty>
            <base-table-empty :is-loading="isLoading">{{ $t('No Services found') }}</base-table-empty>
          </template>
          <template v-slot:cell(enabled)="service">
            <toggle-service-enabled :value="service.item.enabled"
              :name="service.item.name"
              :disabled="true" />
          </template>
          <template v-slot:cell(alive)="service">
            <toggle-service-alive :value="service.item.alive"
              :name="service.item.name"
              :disabled="true" />
          </template>
          <template v-slot:cell(pid)="service">
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
          sort-icon-left
          striped
        >
          <template v-slot:empty>
            <base-table-empty :is-loading="isLoading">{{ $t('No Services found') }}</base-table-empty>
          </template>
          <template v-slot:cell(name)="service">
            <icon v-if="!service.item.alive && service.item.managed"
              name="exclamation-triangle" size="sm" class="text-danger mr-1" v-b-tooltip.hover.top.d300 :title="$t('Service {name} is required with this configuration.', { name: service.item.name})"></icon>
            <icon v-if="service.item.alive && !service.item.managed"
              name="exclamation-triangle" size="sm" class="text-success mr-1" v-b-tooltip.hover.top.d300 :title="$t('Service {name} is not required with this configuration.', { name: service.item.name})"></icon>
            {{ service.item.name }}
          </template>
          <template v-slot:cell(enabled)="service">
            <toggle-service-enabled :value="service.item.enabled"
              :name="service.item.name"
              :disabled="![200, 'error'].includes(service.item.status) || !('enabled' in service.item)" />
          </template>
          <template v-slot:cell(alive)="service">
            <toggle-service-alive :value="service.item.alive"
              :name="service.item.name"
              :disabled="![200, 'error'].includes(service.item.status)" />
          </template>
          <template v-slot:cell(pid)="service">
            <icon v-if="![200, 'error'].includes(service.item.status)" name="circle-notch" spin></icon>
            <span v-else-if="service.item.alive">{{ service.item.pid }}</span>
          </template>
        </b-table>
      </div>
    </b-card>
  </div>
</template>

<script>
import {
  BaseTableEmpty
} from '@/components/new/'
import BaseService from './BaseService'
import ToggleServiceAlive from './ToggleServiceAlive'
import ToggleServiceEnabled from './ToggleServiceEnabled'

const components = {
  BaseService,
  BaseTableEmpty,
  ToggleServiceAlive,
  ToggleServiceEnabled
}

import { computed, onMounted, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  onMounted(() => $store.dispatch('cluster/getConfig', true))
  const servers = computed(() => Object.keys($store.state.cluster.servers))
  const services = computed(() => $store.getters['cluster/servicesByServer'])
  const serviceFields = computed(() => {
    return [
      {
        key: 'service',
        label: i18n.t('Service'),
        sortable: true,
        visible: true
      },
      ...servers.value.map(server => ({
        key: server,
        label: server,
        visible: true,
        tdClass: 'p-0'
      })),
      {
        key: 'actions',
        label: 'CLUSTER',
        visible: true
      }
    ]
  })
  const serviceItems = computed(() => {
    return Object.keys(services.value).map(service => {
      return {
        service,
        ...services.value[service],
        canEnable: Object.values(services.value[service]).filter(service => !service.enabled).length > 0,
        canDisable: Object.values(services.value[service]).filter(service => service.enabled).length > 0,
        canRestart: Object.values(services.value[service]).filter(service => service.alive && service.pid).length > 0,
        canStart: Object.values(services.value[service]).filter(service => !(service.alive && service.pid)).length > 0,
        canStop: Object.values(services.value[service]).filter(service => service.alive && service.pid).length > 0,
      }
    })
  })


  const fields = computed(() => ([
    {
      key: 'name',
      label: i18n.t('Service'),
      sortable: true,
      visible: true
    },
    {
      key: 'enabled',
      label: i18n.t('Enabled'),
      sortable: true,
      visible: true
    },
    {
      key: 'alive',
      label: i18n.t('Running'),
      sortable: true,
      visible: true
    },
    {
      key: 'pid',
      label: i18n.t('PID'),
      sortable: true,
      visible: true
    }
  ]))
  const sortBy = ref('name')
  const sortDesc = ref(false)

  const blacklistedServices = computed(() => $store.getters[`$_status/blacklistedServices`])
  const isLoading = computed(() => $store.getters[`$_status/isServicesLoading`])
  const isStopping = computed(() => $store.getters[`$_status/isServicesStopping`])
  const isStarting = computed(() => $store.getters[`$_status/isServicesStarting`])
  const isRestarting = computed(() => $store.getters[`$_status/isServicesRestarting`])
  const manageableServices = computed(() => $store.state['$_status'].services.filter(service => !(blacklistedServices.value.includes(service.name))))
  const protectedServices = computed(() => $store.state['$_status'].services.filter(service => blacklistedServices.value.includes(service.name)))

  $store.dispatch(`$_status/getServices`)

  const stopAllServices = () => {
    $store.dispatch('notification/info', { message: i18n.t('Stopping all services.') })
    $store.dispatch(`$_status/stopAllServices`).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('All services stopped.') })
    })
  }
  const startAllServices = () => {
    $store.dispatch('notification/info', { message: i18n.t('Starting all services.') })
    $store.dispatch(`$_status/startAllServices`).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('All services started.') })
    })
  }
  const restartAllServices = () => {
    $store.dispatch('notification/info', { message: i18n.t('Restarting all services.') })
    $store.dispatch(`$_status/restartAllServices`).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('All services restarted.') })
    })
  }
  const isBlacklisted = service => {
    return blacklistedServices.value.includes(service.name)
  }

  return {
    fields,
    sortBy,
    sortDesc,
    blacklistedServices,
    isLoading,
    isStopping,
    isStarting,
    isRestarting,
    manageableServices,
    protectedServices,
    stopAllServices,
    startAllServices,
    restartAllServices,
    isBlacklisted,

    serviceFields,
    serviceItems,
    servers,
    services
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  setup
}
</script>
