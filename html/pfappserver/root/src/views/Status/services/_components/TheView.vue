<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Services'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-table ref="tableRef"
        :busy="isLoading"
        :hover="serviceItems.length > 0"
        :items="serviceItems"
        :fields="serviceFields"
        :sort-by="'service'"
        :sort-desc="false"
        class="mb-0"
        show-empty
        responsive
        sort-icon-left
        striped
        selectable
        @row-selected="onRowSelected"
      >
        <template v-slot:empty>
          <base-table-empty :is-loading="isLoading">{{ $i18n.t('No Services found') }}</base-table-empty>
        </template>
        <template #head(selected)>
          <span @click.stop.prevent="onAllSelected">
            <template v-if="selected.length > 0">
              <icon name="check-square" class="bg-white text-success" scale="1.125" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
            </template>
          </span>
        </template>
        <template #head(actions)>
          <b-row class="align-items-center">
            <b-col cols="auto" class="mr-auto">CLUSTER</b-col>
            <b-col>
              <b-dropdown size="sm" variant="link" class="float-right">
                <template #button-content>
                  <icon class="ml-1" name="directions" /> {{ $i18n.t('API Redirect') }}
                </template>
                  <b-dropdown-item @click="setApiServer()" :active="isApiServer(null)">{{ $i18n.t('None') }}</b-dropdown-item>
                  <b-dropdown-item v-for="({ management_ip }, server) in apiServers" :key="server" @click="setApiServer(server)" :active="isApiServer(server)">
                    {{ server }} ({{ management_ip }})
                  </b-dropdown-item>
              </b-dropdown>
            </b-col>
          </b-row>
        </template>
        <template #top-row v-if="selected.length">
        <base-button-bulk-actions
          :selectedItems="selectedItems" :visibleColumns="serviceFields" class="my-3" />
        </template>
        <template #cell(selected)="{ index, rowSelected }">
          <span @click.stop="onItemSelected(index)">
            <template v-if="rowSelected">
              <icon name="check-square" class="bg-white text-success" scale="1.125" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
            </template>
          </span>
        </template>
        <template v-slot:cell(service)="{ value }">
          {{ value }}
        </template>
        <template v-slot:cell(actions)="{ item: { service, isProtected, hasAlive, hasDead, hasDisabled, hasEnabled } }">
          <b-button v-if="hasDisabled"
            class="m-1" variant="outline-primary" @click="doEnableAll(service)" :disabled="isLoading"><icon name="toggle-on" class="mr-1" /> {{ $i18n.t('Enable All') }}</b-button>
          <b-button v-if="hasEnabled"
            class="m-1" variant="outline-primary" @click="doDisableAll(service)" :disabled="isLoading"><icon name="toggle-off" class="mr-1" /> {{ $i18n.t('Disable All') }}</b-button>
          <b-button v-if="hasAlive && !isProtected"
            class="m-1" variant="outline-primary" @click="doRestartAll(service)" :disabled="isLoading"><icon name="redo" class="mr-1" /> {{ $i18n.t('Restart All') }}</b-button>
          <b-button v-if="hasDead && !isProtected"
            class="m-1" variant="outline-primary" @click="doStartAll(service)" :disabled="isLoading"><icon name="play" class="mr-1" /> {{ $i18n.t('Start All') }}</b-button>
          <b-button v-if="hasAlive && !isProtected"
            class="m-1" variant="outline-primary" @click="doStopAll(service)" :disabled="isLoading"><icon name="stop" class="mr-1" /> {{ $i18n.t('Stop All') }}</b-button>
        </template>
        <template v-slot:cell()="{ item, value }">
          <base-service :id="item.service" :server="value.server" :key="`${value.server}-${item.service}`" lazy
            enable disable restart start stop />
        </template>
      </b-table>
      <b-container fluid v-if="selected.length"
        class="p-0">
        <base-button-bulk-actions
          :selectedItems="selectedItems" :visibleColumns="serviceFields" class="m-3" />
      </b-container>
    </div>
  </b-card>
</template>

<script>
import {
  BaseTableEmpty
} from '@/components/new/'
import BaseButtonBulkActions from './BaseButtonBulkActions'
import BaseService from './BaseService'

const components = {
  BaseButtonBulkActions,
  BaseService,
  BaseTableEmpty
}

import { computed, customRef, onMounted, ref } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import i18n from '@/utils/locale'
import { localeStrings } from '../config'

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  onMounted(() => $store.dispatch('cluster/getConfig', true))
  const isCluster = computed(() => $store.getters['cluster/isCluster'])
  const isLoading = computed(() => $store.getters['cluster/isLoading'])
  const servers = computed(() => Object.keys($store.state.cluster.servers))
  const services = computed(() => $store.getters['cluster/servicesByServer'])
  const serviceFields = computed(() => {
    return [
      {
        key: 'selected',
        thStyle: 'width: 40px;', tdClass: 'text-center',
        locked: true,
        stickyColumn: true,

      },
      {
        key: 'service',
        tdClass: 'text-nowrap',
        label: i18n.t('Service'),
        sortable: true,
        visible: true,
        stickyColumn: true,
      },
      ...servers.value.map(server => ({
        key: server,
        label: server,
        visible: true,
        tdClass: 'px-0'
      })),
      ...((isCluster.value)
        ? [ { key: 'actions', label: 'CLUSTER', visible: true } ]
        : []
      )
    ]
  })

  const serviceItems = computed(() => {
    return Object.keys(services.value).map(service => {
      const { servers, ...rest } = services.value[service]
      return {
        service,
        ...rest,
        ...Object.keys(services.value[service].servers).reduce((servers, server) => {
          return { ...servers, [server]: { server, ...services.value[service].servers[server] } }
        }, {})
      }
    })
  })

  const doEnableAll = service => $store.dispatch('cluster/enableServiceCluster', service).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_ENABLED_SUCCESS, { services: `<code>${service}</code>` }) })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_ENABLED_ERROR, { services: `<code>${service}</code>` }) })
  })

  const doDisableAll = service => $store.dispatch('cluster/disableServiceCluster', service).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_DISABLED_SUCCESS, { services: `<code>${service}</code>` }) })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_DISABLED_ERROR, { services: `<code>${service}</code>` }) })
  })

  const doRestartAll = service => $store.dispatch('cluster/restartServiceCluster', service).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_RESTARTED_SUCCESS, { services: `<code>${service}</code>` }) })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_RESTARTED_ERROR, { services: `<code>${service}</code>` }) })
  })

  const doStartAll = service => $store.dispatch('cluster/startServiceCluster', service).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STARTED_SUCCESS, { services: `<code>${service}</code>` }) })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STARTED_ERROR, { services: `<code>${service}</code>` }) })
  })

  const doStopAll = service => $store.dispatch('cluster/stopServiceCluster', service).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STOPPED_SUCCESS, { services: `<code>${service}</code>` }) })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STOPPED_ERROR, { services: `<code>${service}</code>` }) })
  })

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, serviceItems, 'service')

  const apiServer = customRef((track, trigger) => ({
    get() {
      track()
      return localStorage.getItem('X-PacketFence-Server') || null
    },
    set(newValue) {
      localStorage.setItem('X-PacketFence-Server', newValue)
      $router.go() // reload
      trigger()
    }
  }))
  const apiServers = computed(() => $store.state.cluster.servers)
  const isApiServer = host => {
    const { [host]: { management_ip: _apiServer = null } = {} } = $store.state.cluster.servers
    return _apiServer === host
  }
  const setApiServer = (host = null) => {
    if (host) {
      const { [host]: { management_ip: _apiServer } = {} } = $store.state.cluster.servers
    if (_apiServer) {
        apiServer.value = _apiServer
        return
      }
    }
    apiServer.value = null
  }

  return {
    serviceFields,
    serviceItems,
    servers,
    services,
    isCluster,
    isLoading,
    doEnableAll,
    doDisableAll,
    doRestartAll,
    doStartAll,
    doStopAll,

    tableRef,
    ...selected,

    apiServer,
    apiServers,
    isApiServer,
    setApiServer,
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  setup
}
</script>
