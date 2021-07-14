<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Cluster Services'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-table
        :fields="fields"
        :items="items"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        :hover="services.length > 0"
        show-empty
        responsive
        fixed
        sort-icon-left
        striped
      >
        <template v-slot:empty>
          <base-table-empty :is-loading="isLoading">{{ $t('No services found') }}</base-table-empty>
        </template>
        <template v-for="server in servers" v-slot:[head(server)]="data">
          <span :key="server.host">
            {{ data.label }}
            <b-button v-if="!isApiServer(server)" size="sm" variant="outline-success" class="ml-1" @click.stop.prevent="setApiServer(server)">{{ $t('Start Redirect') }} <icon class="ml-1" name="directions" /></b-button>
            <b-button v-else size="sm" variant="outline-danger" class="ml-1" @click.stop.prevent="setApiServer()">{{ $t('Cancel Redirect') }} <icon class="ml-1" name="times" /></b-button>
          </span>
        </template>
        <template v-for="server in servers" v-slot:[cell(server)]="{ item: { [server]: status } }">
          <div class="container-status small" v-if="status" :key="server">
            <b-row class="row-nowrap">
                <b-col>{{ $t('Alive') }}</b-col>
                <b-col cols="auto">
                  <b-badge v-if="status.alive && status.pid" pill variant="success">{{ status.pid }}</b-badge>
                  <icon v-else class="text-danger" name="circle" />
                </b-col>
            </b-row>
            <b-row class="row-nowrap">
                <b-col>{{ $t('Enabled') }}</b-col>
                <b-col cols="auto"><icon :class="(status.enabled) ? 'text-success' : 'text-danger'" name="circle" /></b-col>
            </b-row>
            <b-row class="row-nowrap">
                <b-col>{{ $t('Managed') }}</b-col>
                <b-col cols="auto"><icon :class="(status.managed) ? 'text-success' : 'text-danger'" name="circle" /></b-col>
            </b-row>
          </div>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import {
  BaseTableEmpty
} from '@/components/new/'

const components = {
  BaseTableEmpty
}

import { computed, customRef, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const sortBy = ref('service')
  const sortDesc = ref(false)

  $store.dispatch('$_status/getClusterServices')
  const isLoading = computed(() => $store.getters[`$_status/isClusterServicesLoading`])
  const servers = computed(() => $store.state.$_status.clusterServices.map(server => server.host))
  const cluster = computed(() => $store.state.$_status.cluster)

  const _uniqueServices = (...services) => [ ...new Set([].concat(...services)) ]
  const services = computed(() => {
    const allServices = $store.state.$_status.clusterServices
      .map(server => server.services.map(service => service.id))
    return _uniqueServices(...allServices)
  })

  const fields = computed(() => {
    return [
      { key: 'service', label: i18n.t('Service'), sortable: true }
    ].concat(servers.value.map(server => {
      return { key: server, label: server, sortable: false }
    }))
  })
  const items = computed(() => {
    return services.value
      .map(service => {
        let statuses = { service }
        servers.value.forEach(server => {
          const { services = {} } = $store.state.$_status.clusterServices.find(o => o.host === server)
          const status = services.find(o => o.id === service)
          statuses[server] = status
        })
        return statuses
      })
  })
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

  const cell = name => {
    return `cell(${name})`
  }
  const head = name => {
    return `head(${name})`
  }
  const isApiServer = host => {
    const { management_ip: _apiServer = null } = cluster.value.find(server => server.host === host)
    return _apiServer === apiServer.value
  }
  const setApiServer = (host = null) => {
    if (host) {
      const { management_ip: _apiServer = null } = cluster.value.find(server => server.host === host)
      if (_apiServer) {
        apiServer.value = _apiServer
        return
      }
    }
    apiServer.value = null
  }

  return {
    sortBy,
    sortDesc,
    isLoading,
    servers,
    cluster,
    services,
    fields,
    items,
    apiServer,
    cell,
    head,
    isApiServer,
    setApiServer
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  setup
}
</script>

<style lang="scss">
.container-status {
    max-width: 200px;
}
</style>
