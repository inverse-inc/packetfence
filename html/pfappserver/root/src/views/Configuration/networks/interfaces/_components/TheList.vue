<template>
  <div>
    <b-card no-body>
      <b-card-header>
        <b-row class="align-items-center px-0" no-gutters>
          <b-col cols="auto" class="mr-auto">
            <h4 class="d-inline mb-0" v-t="'Interfaces & Networks'"></h4>
          </b-col>
          <b-col v-if="highlightedRoute" cols="auto" align="right" class="flex-grow-0">
            <icon name="exchange-alt" class="text-primary mr-1" size="lg"></icon> {{ highlightedRoute }}
          </b-col>
        </b-row>
      </b-card-header>
      <div class="card-body mb-3">
        <b-table class="table-clickable"
          :items="interfaces"
          :fields="fieldsInterface"
          :sort-by="'id'"
          :sort-desc="false"
          :sort-compare="sortCompareInterface"
          :hover="interfaces && interfaces.length > 0"
          @row-clicked="onRowClickInterface"
          @row-hovered="onRowHoverInterface"
          show-empty
          responsive
          fixed
          sort-icon-left
        >
          <template v-slot:empty>
            <base-table-empty :is-loading="isInterfacesLoading">{{ $t('No interfaces found') }}</base-table-empty>
          </template>
          <template v-slot:cell(is_running)="{ item }">
             <toggle-status :value="item.is_running"
              :disabled="item.type === 'management' || isInterfacesLoading"
              :item="item" />
          </template>
          <template v-slot:cell(id)="item">
            <span class="text-nowrap mr-2">{{ item.item.name }}</span>
            <b-badge v-if="item.item.vlan" variant="secondary">VLAN {{ item.item.vlan }}</b-badge>
          </template>
          <template v-slot:cell(network)="item">
            <router-link v-if="layer2NetworksIds.includes(item.value)" :to="{ name: 'layer2_network', params: { id: item.value } }">{{ item.value }}</router-link>
            <template v-else>{{ item.value }}</template>
          </template>
          <template v-slot:cell(additional_listening_daemons)="item">
            <b-badge v-for="(daemon, index) in item.item.additional_listening_daemons" :key="index" class="mr-1" variant="secondary">{{ daemon }}</b-badge>
          </template>
          <template v-slot:cell(high_availability)="item">
            <icon name="circle" :class="{ 'text-success': item.item.high_availability === 1, 'text-danger': item.item.high_availability === 0 }"></icon>
          </template>
          <template v-slot:cell(buttons)="item">
            <template v-if="!item.item.not_editable">
              <span v-if="item.item.vlan"
                class="float-right text-nowrap"
              >
                <base-button-confirm
                  size="sm" variant="outline-danger" class="my-1 mr-1" reverse
                  :disabled="isInterfacesLoading"
                  :confirm="$t('Delete VLAN?')"
                  @click="removeInterface(item.item)"
                >{{ $t('Delete') }}</base-button-confirm>
                <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isInterfacesLoading" @click.stop.prevent="cloneInterface(item.item)">{{ $t('Clone') }}</b-button>
              </span>
              <span v-else
                class="float-right text-nowrap"
              >
                <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isInterfacesLoading" @click.stop.prevent="addVlanInterface(item.item)">{{ $t('New VLAN') }}</b-button>
              </span>
            </template>
          </template>
        </b-table>
      </div>
    </b-card>

    <b-card class="mt-3" no-body>
      <b-card-header>
        <b-row class="align-items-center px-0" no-gutters>
          <b-col cols="auto" class="mr-auto">
            <h4 class="d-inline mb-0" v-t="'Layer2 Networks'"></h4>
          </b-col>
          <b-col v-if="highlightedRoute" cols="auto" align="right" class="flex-grow-0">
            <icon name="exchange-alt" class="text-primary mr-1" size="lg"></icon> {{ highlightedRoute }}
          </b-col>
        </b-row>
      </b-card-header>
      <div class="card-body">
        <b-row align-h="end" align-v="start" class="mb-3">
          <b-col cols="auto" class="mr-auto"></b-col>
          <b-col cols="auto">
            <base-button-service service="iptables" restart start stop class="mr-1" />
            <base-button-service service="pfdhcp" restart start stop class="mr-1" />
            <base-button-service service="pfdns" restart start stop class="mr-1" />
          </b-col>
        </b-row>
        <b-table class="table-clickable"
          :items="layer2Networks"
          :fields="fieldsLayer2Network"
          :sort-by="'id'"
          :sort-desc="false"
          :hover="layer2Networks && layer2Networks.length > 0"
          @row-clicked="onRowClickLayer2Network"
          @row-hovered="onRowHoverLayer2Network"
          show-empty
          responsive
          fixed
          sort-icon-left
        >
          <template v-slot:empty>
            <base-table-empty :is-loading="isLayer2NetworksLoading">{{ $t('No layer2 networks found') }}</base-table-empty>
          </template>
          <template v-slot:cell(dhcpd)="item">
            <icon name="circle" :class="{ 'text-success': item.item.dhcpd === 'enabled', 'text-danger': item.item.dhcpd === 'disabled' }"></icon>
          </template>
          <template v-slot:cell(netflow_accounting_enabled)="item">
            <icon name="circle" :class="{ 'text-success': item.item.netflow_accounting_enabled === 'enabled', 'text-danger': item.item.netflow_accounting_enabled === 'disabled' }"></icon>
          </template>
        </b-table>
      </div>
    </b-card>

    <b-card class="mt-3" no-body>
      <b-card-header>
        <b-row class="align-items-center px-0" no-gutters>
          <b-col cols="auto" class="mr-auto">
            <h4 class="d-inline mb-0" v-t="'Routed Networks'"></h4>
          </b-col>
          <b-col v-if="highlightedRoute" cols="auto" align="right" class="flex-grow-0">
            <icon name="exchange-alt" class="text-primary mr-1" size="lg"></icon> {{ highlightedRoute }}
          </b-col>
        </b-row>
      </b-card-header>
      <div class="card-body">
        <b-row align-h="end" align-v="start" class="mb-3">
          <b-col cols="auto" class="mr-auto">
            <b-button variant="outline-primary" class="mr-1" :to="{ name: 'newRoutedNetwork' }">{{ $t('New Routed Network') }}</b-button>
          </b-col>
          <b-col cols="auto">
            <base-button-service service="keepalived" restart start stop class="mr-1" />
            <base-button-service service="iptables" restart start stop class="mr-1" />
            <base-button-service service="pfdhcp" restart start stop class="mr-1" />
            <base-button-service service="pfdns" restart start stop class="mr-1" />
          </b-col>
        </b-row>
        <b-table class="table-clickable"
          :items="routedNetworks"
          :fields="fieldsRoutedNetwork"
          :sort-by="'id'"
          :sort-desc="false"
          :hover="routedNetworks && routedNetworks.length > 0"
          @row-clicked="onRowClickRoutedNetwork"
          @row-hovered="onRowHoverRoutedNetwork"
          show-empty
          responsive
          fixed
          sort-icon-left
        >
          <template v-slot:empty>
            <base-table-empty :is-loading="isRoutedNetworksLoading">{{ $t('No routed networks found') }}</base-table-empty>
          </template>
          <template v-slot:cell(dhcpd)="item">
            <icon name="circle" :class="{ 'text-success': item.item.dhcpd === 'enabled', 'text-danger': item.item.dhcpd === 'disabled' }"></icon>
          </template>
          <template v-slot:cell(netflow_accounting_enabled)="item">
            <icon name="circle" :class="{ 'text-success': item.item.netflow_accounting_enabled === 'enabled', 'text-danger': item.item.netflow_accounting_enabled === 'disabled' }"></icon>
          </template>
          <template v-slot:cell(buttons)="item">
            <span class="float-right text-nowrap">
              <base-button-confirm
                size="sm" variant="outline-danger" class="my-1 mr-1" reverse
                :disabled="isRoutedNetworksLoading"
                :confirm="$t('Delete Routed Network?')"
                @click="removeRoutedNetwork(item.item)"
              >{{ $t('Delete') }}</base-button-confirm>
              <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isRoutedNetworksLoading" @click.stop.prevent="cloneRoutedNetwork(item.item)">{{ $t('Clone') }}</b-button>
            </span>
          </template>
        </b-table>
      </div>
    </b-card>
  </div>
</template>

<script>
import {
  BaseButtonConfirm,
  BaseButtonService,
  BaseTableEmpty
} from '@/components/new/'
import { ToggleStatus } from '@/views/Configuration/networks/interfaces/_components/'

const components = {
  BaseButtonConfirm,
  BaseButtonService,
  BaseTableEmpty,
  ToggleStatus
}

import { computed, onMounted, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import network from '@/utils/network'
import { columns as columnsInterface } from '@/views/Configuration/networks/interfaces/config'
import { columns as columnsLayer2Network } from '@/views/Configuration/networks/layer2Networks/config'
import { columns as columnsRoutedNetwork } from '@/views/Configuration/networks/routedNetworks/config'

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const highlightedRoute = ref(null)

  /**
   * Interfaces
   */
  const isInterfacesLoading = computed(() => $store.getters['_interfaces/isLoading'])
  const isInterfacesWaiting = computed(() => $store.getters['$_interfaces/isWaiting'])
  const interfaces = computed(() => $store.getters['$_interfaces/interfaces']
    .map(item => {
      const isHighlightedRoute = (highlightedRoute.value && item.ipaddress && item.network && network.ipv4NetmaskToSubnet(item.ipaddress, item.network) === highlightedRoute.value)
      if (isHighlightedRoute)
        item._rowVariant = 'primary'
      else if (item.not_editable)
        item._rowVariant = 'warning' // set table row variant on not editable
      else if (item.vlan)
        item._rowVariant = 'secondary' // set table row variant on vlans
      return item
    })
  )
  const fieldsInterface = computed(() => columnsInterface.map(column => {
    const { label } = column
    return { ...column, label: i18n.t(label) }
  }))
  const cloneInterface = params => $router.push({ name: 'cloneInterface', params })
  const removeInterface = item => $store.dispatch(`$_interfaces/deleteInterface`, item.id)
  const addVlanInterface = params => $router.push({ name: 'newInterface', params })
  const onRowClickInterface = params => {
    const { not_editable } = params
    if (not_editable)
      $store.dispatch('notification/danger', { message: i18n.t('Interface <code>{id}</code> must be up in order to be modified.', params) })
    else
      $router.push({ name: 'interface', params })
  }
  const onRowHoverInterface = item => {
    if (item.ipaddress && item.netmask) {
      let subnet = network.ipv4NetmaskToSubnet(item.ipaddress, item.netmask)
      if (layer2Networks.value.find(layer2 => layer2.id === subnet)) {
        highlightedRoute.value = subnet
        return
      }
      if (routedNetworks.value.find(route => route.id === subnet)) {
        highlightedRoute.value = subnet
        return
      }
    }
    highlightedRoute.value = null
  }
  const sortCompareInterface = (itemA, itemB, key, sortDesc) => {
    if (fieldsInterface.value.filter(field => { return field.key === key && field.sort }).length > 0) {
      return fieldsInterface.value
        .find(field => { return field.key === key && field.sort })
        .sort(itemA, itemB, sortDesc) // custom sort
    }
    return null // default sort
  }

  /**
   * Layer2 Networks
   */
  const isLayer2NetworksLoading = computed(() => $store.getters['$_layer2_networks/isLoading'])
  const isLayer2NetworksWaiting = computed(() => $store.getters['$_layer2_networks/isWaiting'])
  const layer2Networks = computed(() => $store.getters['$_layer2_networks/layer2Networks']
    .map(item => {
      const isHighlightedRoute = (highlightedRoute.value && item.id === highlightedRoute.value)
      if (isHighlightedRoute)
        item._rowVariant = 'primary'
      else
        item._rowVariant = null
      return item
    })
  )
  const layer2NetworksIds = computed(() => layer2Networks.value.map(network => network.id))
  const fieldsLayer2Network = computed(() => columnsLayer2Network.map(column => {
    const { label } = column
    return { ...column, label: i18n.t(label) }
  }))
  const onRowClickLayer2Network = params => $router.push({ name: 'layer2_network', params })
  const onRowHoverLayer2Network = item => {
    if (interfaces.value.find(iface => iface.ipaddress && iface.netmask && network.ipv4NetmaskToSubnet(iface.ipaddress, iface.netmask) === item.id)) {
      highlightedRoute.value = item.id
      return
    }
    highlightedRoute.value = null
  }

  /**
   * Routed Networks
   */
  const isRoutedNetworksLoading = computed(() => $store.getters['$_routed_networks/isLoading'])
  const isRoutedNetworksWaiting = computed(() => $store.getters['$_routed_networks/isWaiting'])
  const routedNetworks = computed(() => $store.getters['$_routed_networks/routedNetworks']
    .map(item => {
      const isHighlightedRoute = (highlightedRoute.value && item.id === highlightedRoute.value)
      if (isHighlightedRoute)
        item._rowVariant = 'primary'
      else
        item._rowVariant = null
      return item
    })
  )
  const fieldsRoutedNetwork = computed(() => columnsRoutedNetwork.map(column => {
    const { label } = column
    return { ...column, label: i18n.t(label) }
  }))
  const cloneRoutedNetwork = params => $router.push({ name: 'cloneRoutedNetwork', params })
  const removeRoutedNetwork = item => $store.dispatch(`$_routed_networks/deleteRoutedNetwork`, item.id)
  const onRowClickRoutedNetwork = params => $router.push({ name: 'routed_network', params })
  const onRowHoverRoutedNetwork = item => {
    if (interfaces.value.find(iface => iface.ipaddress && iface.netmask && network.ipv4NetmaskToSubnet(iface.ipaddress, iface.netmask) === item.id)) {
      highlightedRoute.value = item.id
      return
    }
    highlightedRoute.value = null
  }

  onMounted(() => {
    $store.dispatch('$_interfaces/all')
    $store.dispatch('$_routed_networks/all')
    $store.dispatch('$_layer2_networks/all')
  })

  return {
    highlightedRoute,

    // interfaces
    isInterfacesLoading,
    isInterfacesWaiting,
    interfaces,
    fieldsInterface,
    cloneInterface,
    removeInterface,
    addVlanInterface,
    onRowClickInterface,
    onRowHoverInterface,
    sortCompareInterface,

    // layer 2 networks
    isLayer2NetworksLoading,
    isLayer2NetworksWaiting,
    layer2Networks,
    layer2NetworksIds,
    fieldsLayer2Network,
    onRowClickLayer2Network,
    onRowHoverLayer2Network,

    // routed networks
    isRoutedNetworksLoading,
    isRoutedNetworksWaiting,
    routedNetworks,
    fieldsRoutedNetwork,
    cloneRoutedNetwork,
    removeRoutedNetwork,
    onRowClickRoutedNetwork,
    onRowHoverRoutedNetwork
  }
}

// @vue/component
export default {
  name: 'the-list',
  components,
  setup
}
</script>
