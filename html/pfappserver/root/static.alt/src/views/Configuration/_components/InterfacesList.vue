<template>
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
      <div
        @mouseout="unhighlightRoute()"
      >
        <b-table class="table-clickable"
          :items="interfaces"
          :fields="fieldsInterface"
          :sort-by="'id'"
          :sort-desc="false"
          :sort-compare="sortCompareInterface"
          :hover="interfaces && interfaces.length > 0"
          @row-clicked="onRowClickInterface"
          @row-hovered="onRowHoverInterface"
          @mouseout="unhighlightRoute"
          show-empty
          responsive
          fixed
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isInterfacesLoading">{{ $t('No interfaces found') }}</pf-empty-table>
          </template>
          <template slot="is_running" slot-scope="data">
            <pf-form-range-toggle
              v-model="data.item.is_running"
              :values="{ checked: true, unchecked: false }"
              :icons="{ checked: 'check', unchecked: 'times' }"
              :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
              :disabled="isInterfacesLoading"
              @input="toggleRunningInterface(data.item, $event)"
              @click.stop.prevent
            >{{ (data.item.is_running === true) ? $t('up') : $t('down') }}</pf-form-range-toggle>
          </template>
          <template slot="id" slot-scope="data">
            <span class="text-nowrap">{{ data.item.name }}<b-badge v-if="data.item.vlan" class="ml-2" variant="secondary">VLAN {{ data.item.vlan }}</b-badge></span>
          </template>
          <template slot="additional_listening_daemons" slot-scope="data">
            <b-badge v-for="(daemon, index) in data.item.additional_listening_daemons" :key="index" class="mr-1" variant="secondary">{{ daemon }}</b-badge>
          </template>
          <template slot="high_availability" slot-scope="data">
            <icon name="circle" :class="{ 'text-success': data.item.high_availability === 1, 'text-danger': data.item.high_availability === 0 }"></icon>
          </template>
          <template slot="buttons" slot-scope="data">
            <span v-if="data.item.vlan"
              class="float-right text-nowrap"
            >
              <pf-button-delete size="sm" variant="outline-danger" class="mr-1" :disabled="isInterfacesLoading" :confirm="$t('Delete VLAN?')" @on-delete="removeInterface(data.item)" reverse/>
              <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isInterfacesLoading" @click.stop.prevent="cloneInterface(data.item)">{{ $t('Clone') }}</b-button>
            </span>
            <span v-else
              class="float-right text-nowrap"
            >
              <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isInterfacesLoading" @click.stop.prevent="addVlanInterface(data.item)">{{ $t('Add VLAN') }}</b-button>
            </span>
          </template>
        </b-table>
      </div>
    </div>

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
        <b-col>
          <b-button variant="outline-primary" class="mr-1" :to="{ name: 'newRoutedNetwork' }">{{ $t('Add Routed Network') }}</b-button>
          <pf-button-service service="iptables" class="mr-1" restart start stop></pf-button-service>
          <pf-button-service service="routes" class="mr-1" restart start stop></pf-button-service>
          <pf-button-service service="pfdhcp" class="mr-1" restart start stop></pf-button-service>
          <pf-button-service service="pfdns" class="mr-1" restart start stop></pf-button-service>
        </b-col>
        <b-col cols="auto">
          <!-- -->
        </b-col>
      </b-row>
      <div
        @mouseout="unhighlightRoute()"
      >
        <b-table class="table-clickable"
          :items="routedNetworks"
          :fields="fieldsRoutedNetwork"
          :sort-by="'id'"
          :sort-desc="false"
          :sort-compare="sortCompareRoutedNetwork"
          :hover="routedNetworks && routedNetworks.length > 0"
          @row-clicked="onRowClickRoutedNetwork"
          @row-hovered="onRowHoverRoutedNetwork"
          show-empty
          responsive
          fixed
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isRoutedNetworksLoading">{{ $t('No routed networks found') }}</pf-empty-table>
          </template>
          <template slot="dhcpd" slot-scope="data">
            <icon name="circle" :class="{ 'text-success': data.item.dhcpd === 'enabled', 'text-danger': data.item.dhcpd === 'disabled' }"></icon>
          </template>
          <template slot="buttons" slot-scope="data">
            <span class="float-right text-nowrap">
              <pf-button-delete size="sm" variant="outline-danger" class="mr-1" :disabled="isRoutedNetworksLoading" :confirm="$t('Delete Routed Network?')" @on-delete="removeRoutedNetwork(data.item)" reverse/>
              <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isRoutedNetworksLoading" @click.stop.prevent="cloneRoutedNetwork(data.item)">{{ $t('Clone') }}</b-button>
            </span>
          </template>
        </b-table>
      </div>
    </div>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonService from '@/components/pfButtonService'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationInterfacesListColumns as columnsInterface
} from '@/globals/configuration/pfConfigurationInterfaces'
import {
  pfConfigurationRoutedNetworksListColumns as columnsRoutedNetwork
} from '@/globals/configuration/pfConfigurationRoutedNetworks'
import network from '@/utils/network'

export default {
  name: 'InterfacesList',
  components: {
    pfButtonDelete,
    pfButtonService,
    pfEmptyTable,
    pfFormRangeToggle
  },
  data () {
    return {
      interfaces: [], // interfaces from store
      routedNetworks: [], // routed networks from store
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
      return columnsInterface
    },
    isRoutedNetworksLoading () {
      return this.$store.getters[`$_routed_networks/isLoading`]
    },
    isRoutedNetworksWaiting () {
      return this.$store.getters[`$_routed_networks/isWaiting`]
    },
    fieldsRoutedNetwork () {
      return columnsRoutedNetwork
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`$_interfaces/all`).then(data => {
        this.interfaces = data.items
        this.interfaces.forEach((item, index) => {
          if (item.vlan) this.interfaces[index]._rowVariant = 'secondary' // set table row variant on vlans
        })
      })
      this.$store.dispatch(`$_routed_networks/all`).then(data => {
        this.routedNetworks = data.items
      })
    },
    ipv4NetmaskToSubnet (ip, netmask) {
      return network.ipv4NetmaskToSubnet(ip, network)
    },
    /**
     * Interface
     */
    cloneInterface (item) {
      this.$router.push({ name: 'cloneInterface', params: { id: item.id } })
    },
    removeInterface (item) {
      this.$store.dispatch(`$_interfaces/deleteInterface`, item.id).then(response => {
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
        if (this.routedNetworks.find(route => route.id === subnet)) {
          this.highlightedRoute = subnet
          return
        }
      }
      this.highlightedRoute = null
    },
    toggleRunningInterface (item, event) {
      if (!item.is_running) { // inverted logic because our model already changed
        this.$store.dispatch(`$_interfaces/downInterface`, item.id).then(data => {
        }).catch(() => {
          this.init() // reload
        })
      } else {
        this.$store.dispatch(`$_interfaces/upInterface`, item.id).then(data => {
        }).catch(() => {
          this.init() // reload
        })
      }
    },
    sortCompareInterface (itemA, itemB, key, sortDesc) {
      if (this.fieldsInterface.filter(field => { return field.key === key && field.sort }).length > 0) {
        return this.fieldsInterface.find(field => { return field.key === key && field.sort }).sort(itemA, itemB, sortDesc, this) // custom sort
      }
      return null // default sort
    },
    /**
     * Routed Network
     */
    cloneRoutedNetwork (item) {
      this.$router.push({ name: 'cloneRoutedNetwork', params: { id: item.id } })
    },
    removeRoutedNetwork (item) {
      this.$store.dispatch(`$_routed_networks/deleteRoutedNetwork`, item.id).then(response => {
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
    },
    unhighlightRoute () {
      this.highlightedRoute = null
    }
  },
  created () {
    this.init()
  },
  watch: {
    highlightedRoute: {
      handler: function (a, b) {
        if (this.interfaces.length > 0) {
          this.interfaces.forEach((iface, i) => {
            if (a && iface.ipaddress && iface.network && network.ipv4NetmaskToSubnet(iface.ipaddress, iface.network) === a) {
              // highlight
              this.$set(this.interfaces[i], '_rowVariant', 'primary')
            } else {
              // un-highlight
              this.$set(this.interfaces[i], '_rowVariant', (this.interfaces[i].vlan) ? 'secondary' : null)
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
