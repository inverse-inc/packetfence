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
            <pf-empty-table :is-loading="isInterfacesLoading">{{ $t('No interfaces found') }}</pf-empty-table>
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
            <router-link v-if="layer2NetworkIds.includes(item.value)" :to="{ name: 'layer2_network', params: { id: item.value } }">{{ item.value }}</router-link>
            <template v-else>{{ item.value }}</template>
          </template>
          <template v-slot:cell(additional_listening_daemons)="item">
            <b-badge v-for="(daemon, index) in item.item.additional_listening_daemons" :key="index" class="mr-1" variant="secondary">{{ daemon }}</b-badge>
          </template>
          <template v-slot:cell(high_availability)="item">
            <icon name="circle" :class="{ 'text-success': item.item.high_availability === 1, 'text-danger': item.item.high_availability === 0 }"></icon>
          </template>
          <template v-slot:cell(buttons)="item">
            <span v-if="item.item.vlan"
              class="float-right text-nowrap"
            >
              <pf-button-delete size="sm" variant="outline-danger" class="mr-1" :disabled="isInterfacesLoading" :confirm="$t('Delete VLAN?')" @on-delete="removeInterface(item.item)" reverse/>
              <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isInterfacesLoading" @click.stop.prevent="cloneInterface(item.item)">{{ $t('Clone') }}</b-button>
            </span>
            <span v-else
              class="float-right text-nowrap"
            >
              <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isInterfacesLoading" @click.stop.prevent="addVlanInterface(item.item)">{{ $t('New VLAN') }}</b-button>
            </span>
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
            <pf-button-service service="iptables" class="mr-1" restart start stop></pf-button-service>
            <pf-button-service service="pfdhcp" class="mr-1" restart start stop></pf-button-service>
            <pf-button-service service="pfdns" class="mr-1" restart start stop></pf-button-service>
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
            <pf-empty-table :is-loading="isLayer2NetworksLoading">{{ $t('No layer2 networks found') }}</pf-empty-table>
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
            <pf-button-service service="keepalived" class="mr-1" restart start stop></pf-button-service>
            <pf-button-service service="iptables" class="mr-1" restart start stop></pf-button-service>
            <pf-button-service service="pfdhcp" class="mr-1" restart start stop></pf-button-service>
            <pf-button-service service="pfdns" class="mr-1" restart start stop></pf-button-service>
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
            <pf-empty-table :is-loading="isRoutedNetworksLoading">{{ $t('No routed networks found') }}</pf-empty-table>
          </template>
          <template v-slot:cell(dhcpd)="item">
            <icon name="circle" :class="{ 'text-success': item.item.dhcpd === 'enabled', 'text-danger': item.item.dhcpd === 'disabled' }"></icon>
          </template>
          <template v-slot:cell(netflow_accounting_enabled)="item">
            <icon name="circle" :class="{ 'text-success': item.item.netflow_accounting_enabled === 'enabled', 'text-danger': item.item.netflow_accounting_enabled === 'disabled' }"></icon>
          </template>
          <template v-slot:cell(buttons)="item">
            <span class="float-right text-nowrap">
              <pf-button-delete size="sm" variant="outline-danger" class="mr-1" :disabled="isRoutedNetworksLoading" :confirm="$t('Delete Routed Network?')" @on-delete="removeRoutedNetwork(item.item)" reverse/>
              <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isRoutedNetworksLoading" @click.stop.prevent="cloneRoutedNetwork(item.item)">{{ $t('Clone') }}</b-button>
            </span>
          </template>
        </b-table>
      </div>
    </b-card>
  </div>
</template>

<script>
import network from '@/utils/network'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonService from '@/components/pfButtonService'
import pfEmptyTable from '@/components/pfEmptyTable'
import { ToggleStatus } from '@/views/Configuration/networks/interfaces/_components/'
import { columns as columnsInterface } from '../_config/interface'
import { columns as columnsLayer2Network } from '../_config/layer2Network'
import { columns as columnsRoutedNetwork } from '../_config/routedNetwork'

export default {
  name: 'interfaces-list',
  components: {
    pfButtonDelete,
    pfButtonService,
    pfEmptyTable,
    ToggleStatus
  },
  data () {
    return {
      interfaces: [], // interfaces from store
      routedNetworks: [], // routed networks from store
      layer2Networks: [], // layer2 networks from store
      highlightedRoute: null
    }
  },
  computed: {
    isInterfacesLoading () {
      return this.$store.getters[`$_interfaces/isLoading`]
    },
    isInterfacesWaiting () {
      return this.$store.getters[`$_interfaces/isWaiting`]
    },
    fieldsInterface () {
      return columnsInterface.map(column => {
        const { label } = column
        return { ...column, label: this.$i18n.t(label) }
      })
    },
    isLayer2NetworksLoading () {
      return this.$store.getters[`$_layer2_networks/isLoading`]
    },
    isLayer2NetworksWaiting () {
      return this.$store.getters[`$_layer2_networks/isWaiting`]
    },
    fieldsLayer2Network () {
      return columnsLayer2Network.map(column => {
        const { label } = column
        return { ...column, label: this.$i18n.t(label) }
      })
    },
    layer2NetworkIds () {
      return this.layer2Networks.map(network => network.id)
    },
    isRoutedNetworksLoading () {
      return this.$store.getters[`$_routed_networks/isLoading`]
    },
    isRoutedNetworksWaiting () {
      return this.$store.getters[`$_routed_networks/isWaiting`]
    },
    fieldsRoutedNetwork () {
      return columnsRoutedNetwork.map(column => {
        const { label } = column
        return { ...column, label: this.$i18n.t(label) }
      })
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`$_interfaces/all`).then(interfaces => {
        this.interfaces = interfaces
        this.interfaces.forEach((item, index) => {
          if (item.vlan) this.interfaces[index]._rowVariant = 'secondary' // set table row variant on vlans
        })
      })
      this.$store.dispatch(`$_routed_networks/all`).then(routedNetworks => {
        this.routedNetworks = routedNetworks
      })
      this.$store.dispatch(`$_layer2_networks/all`).then(layer2Networks => {
        this.layer2Networks = layer2Networks
      })
    },
    /**
     * Interface
     */
    cloneInterface (item) {
      this.$router.push({ name: 'cloneInterface', params: { id: item.id } })
    },
    removeInterface (item) {
      this.$store.dispatch(`$_interfaces/deleteInterface`, item.id).then(() => {
        this.init() // reload
      })
    },
    addVlanInterface (item) {
      this.$router.push({ name: 'newInterface', params: { id: item.id } })
    },
    onRowClickInterface (item) {
      this.$router.push({ name: 'interface', params: { id: item.id } })
    },
    onRowHoverInterface (item) {
      if (item.ipaddress && item.netmask) {
        let subnet = network.ipv4NetmaskToSubnet(item.ipaddress, item.netmask)
        if (this.layer2Networks.find(layer2 => layer2.id === subnet)) {
          this.highlightedRoute = subnet
          return
        }
        if (this.routedNetworks.find(route => route.id === subnet)) {
          this.highlightedRoute = subnet
          return
        }
      }
      this.highlightedRoute = null
    },
    sortCompareInterface (itemA, itemB, key, sortDesc) {
      if (this.fieldsInterface.filter(field => { return field.key === key && field.sort }).length > 0) {
        return this.fieldsInterface.find(field => { return field.key === key && field.sort }).sort(itemA, itemB, sortDesc, this) // custom sort
      }
      return null // default sort
    },

    /**
     * Layer2 Network
     */
    onRowClickLayer2Network (item) {
      this.$router.push({ name: 'layer2_network', params: { id: item.id } })
    },
    onRowHoverLayer2Network (item) {
      if (this.interfaces.find(iface => iface.ipaddress && iface.netmask && network.ipv4NetmaskToSubnet(iface.ipaddress, iface.netmask) === item.id)) {
        this.highlightedRoute = item.id
        return
      }
      this.highlightedRoute = null
    },

    /**
     * Routed Network
     */
    cloneRoutedNetwork (item) {
      this.$router.push({ name: 'cloneRoutedNetwork', params: { id: item.id } })
    },
    removeRoutedNetwork (item) {
      this.$store.dispatch(`$_routed_networks/deleteRoutedNetwork`, item.id).then(() => {
        this.init() // reload
      })
    },
    onRowClickRoutedNetwork (item) {
      this.$router.push({ name: 'routed_network', params: { id: item.id } })
    },
    onRowHoverRoutedNetwork (item) {
      if (this.interfaces.find(iface => iface.ipaddress && iface.netmask && network.ipv4NetmaskToSubnet(iface.ipaddress, iface.netmask) === item.id)) {
        this.highlightedRoute = item.id
        return
      }
      this.highlightedRoute = null
    }
  },
  created () {
    this.init()
  },
  watch: {
    highlightedRoute: {
      handler: function (a) {
        if (this.interfaces.length > 0) {
          this.interfaces.forEach((iface, i) => {
            if (a && iface.ipaddress && iface.network && network.ipv4NetmaskToSubnet(iface.ipaddress, iface.network) === a) {
              this.$set(this.interfaces[i], '_rowVariant', 'primary')
            } else {
              this.$set(this.interfaces[i], '_rowVariant', (this.interfaces[i].vlan) ? 'secondary' : null)
            }
          })
        }
        if (this.layer2Networks.length > 0) {
          this.layer2Networks.forEach((layer2, i) => {
            if (a && layer2.id && layer2.id === a) {
              this.$set(this.layer2Networks[i], '_rowVariant', 'primary')
            } else {
              this.$set(this.layer2Networks[i], '_rowVariant', null)
            }
          })
        }
        if (this.routedNetworks.length > 0) {
          this.routedNetworks.forEach((route, i) => {
            if (a && route.id && route.id === a) {
              this.$set(this.routedNetworks[i], '_rowVariant', 'primary')
            } else {
              this.$set(this.routedNetworks[i], '_rowVariant', null)
            }
          })
        }
      }
    }
  }
}
</script>
