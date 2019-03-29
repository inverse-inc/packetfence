<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-3" v-t="'Interfaces & Networks'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-row align-h="end" align-v="start" class="mb-3">
        <b-col>
          <b-button variant="outline-primary" :to="{ name: 'newRoutedNetwork' }">{{ $t('Add Routed Network') }}</b-button>
        </b-col>
        <b-col cols="auto">
          <!-- -->
        </b-col>
      </b-row>
      <b-table class="table-clickable"
        :items="items"
        :fields="fields"
        :sort-by="'id'"
        :sort-desc="false"
        :sort-compare="sortCompare"
        :hover="items.length > 0"
        @row-clicked="onRowClick"
        show-empty
        responsive
        fixed
      >
        <template slot="empty" v-bind="{ isLoading }">
          <pf-empty-table :isLoading="isLoading">{{ $t('No interfaces found') }}</pf-empty-table>
        </template>
        <template slot="is_running" slot-scope="data">
          <pf-form-range-toggle
            v-model="data.item.is_running"
            :values="{ checked: true, unchecked: false }"
            :icons="{ checked: 'check', unchecked: 'times' }"
            :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
            :disabled="isLoading"
            @input="toggleRunning(data.item, $event)"
            @click.stop.prevent
          >{{ (data.item.is_running === true) ? $t('up') : $t('down') }}</pf-form-range-toggle>
        </template>
        <template slot="id" slot-scope="data">
          <span class="text-nowrap">{{ data.item.name }}<b-badge v-if="data.item.vlan" class="ml-2" variant="secondary">VLAN {{ data.item.vlan }}</b-badge></span>
        </template>
        <template slot="additional_listening_daemons" slot-scope="data">
          <b-badge v-for="(daemon, index) in data.item.additional_listening_daemons" :key="index" class="mr-1" variant="secondary">{{ daemon }}</b-badge>
        </template>
        <template slot="buttons" slot-scope="data">
          <span v-if="data.item.vlan"
            class="float-right text-nowrap"
          >
            <pf-button-delete size="sm" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete VLAN?')" @on-delete="remove(data.item)" reverse/>
            <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isLoading" @click.stop.prevent="clone(data.item)">{{ $t('Clone') }}</b-button>
          </span>
          <span v-else
            class="float-right text-nowrap"
          >
            <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isLoading" @click.stop.prevent="addVlan(data.item)">{{ $t('Add VLAN') }}</b-button>
          </span>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationInterfacesListColumns as columns/*,
  pfConfigurationInterfacesListFields as fields*/
} from '@/globals/configuration/pfConfigurationInterfaces'
import network from '@/utils/network'

export default {
  name: 'InterfacesList',
  components: {
    pfButtonDelete,
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
  data () {
    return {
      items: [] // interfaces from store
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isInterfacesLoading`]
    },
    isWaiting () {
      return this.$store.getters[`${this.storeName}/isInterfacesWaiting`]
    },
    fields () {
      return columns
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.storeName}/all`).then(data => {
console.log('data', data)
        this.items = JSON.parse(JSON.stringify(data.items))
        this.items.forEach((item, index) => {
          if (item.vlan) this.items[index]._rowVariant = 'secondary' // set table row variant on vlans
        })
      })
    },
    clone (item) {
      this.$router.push({ name: 'cloneInterface', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteInterface`, item.id).then(response => {
        this.init() // reload
      })
    },
    addVlan (item) {
console.log('add vlan', item)
    },
    onRowClick (item) {
      this.$router.push({ name: 'interface', params: { id: item.id } })
    },
    toggleRunning (item, event) {
      if (!item.is_running) { // inverted logic because our model already changed
        this.$store.dispatch(`${this.storeName}/downInterface`, item.id).then(data => {
        }).catch(() => {
          this.init() // reload
        })
      } else {
        this.$store.dispatch(`${this.storeName}/upInterface`, item.id).then(data => {
        }).catch(() => {
          this.init() // reload
        })
      }
    },
    ipv4NetmaskToSubnet (ip, netmask) {
      return network.ipv4NetmaskToSubnet(ip, network)
    },
    sortCompare (itemA, itemB, key, sortDesc) {
      if (this.fields.filter(field => { return field.key === key && field.sort }).length > 0) {
        return this.fields.find(field => { return field.key === key && field.sort }).sort(itemA, itemB, sortDesc, this) // custom sort
      }
      return null // default sort
    }
  },
  created () {
    this.init()
  }
}
</script>
