<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Interfaces & Networks'"></h4>
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
          <pf-empty-table :isLoading="isInterfacesLoading">{{ $t('No interfaces found') }}</pf-empty-table>
        </template>
        <template v-slot:cell(is_running)="{ item }">
          <pf-form-range-toggle
            v-model="item.is_running"
            :values="{ checked: true, unchecked: false }"
            :icons="{ checked: 'check', unchecked: 'times' }"
            :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
            :right-labels="{ checked: $t('up'), unchecked: $t('down') }"
            :lazy="{ checked: enableInterface(item), unchecked: disableInterface(item) }"
            :disabled="item.type === 'management'"
            @click.stop.prevent
          />
        </template>
        <template v-slot:cell(id)="item">
          <span class="text-nowrap mr-2">{{ item.item.name }}</span>
          <b-badge v-if="item.item.vlan" variant="secondary">VLAN {{ item.item.vlan }}</b-badge>
        </template>
        <!-- <template v-slot:cell(additional_listening_daemons)="item">
          <b-badge v-for="(daemon, index) in item.item.additional_listening_daemons" :key="index" class="mr-1" variant="secondary">{{ daemon }}</b-badge>
        </template> -->
        <template v-slot:cell(ipaddress)="{ item }">
          <ip>{{ item.ipaddress }}</ip><ip v-if="item.netmask" class="text-black-50">/{{ item.netmask }}</ip>
          <br/>
          <ip>{{ item.ipv6_address }}</ip><ip v-if="item.ipv6_prefix" class="text-black-50">{{ item.ipv6_prefix }}</ip>
        </template>
        <template v-slot:cell(type)="{ item }">
          {{ item.type }}
          <b-badge v-for="(daemon, index) in item.additional_listening_daemons" :key="index" class="mr-1" variant="secondary">{{ daemon }}</b-badge>
        </template>
        <!-- <template v-slot:cell(high_availability)="item">
          <icon name="circle" :class="{ 'text-success': item.item.high_availability === 1, 'text-danger': item.item.high_availability === 0 }"></icon>
        </template> -->
        <template v-slot:cell(buttons)="{ item }">
          <span v-if="item.vlan"
            class="float-right text-nowrap"
          >
            <pf-button-delete size="sm" variant="outline-danger" class="mr-1" :disabled="isInterfacesLoading" :confirm="$t('Delete VLAN?')" @on-delete="removeInterface(item)" reverse/>
            <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isInterfacesLoading" @click.stop.prevent="cloneInterface(item)">{{ $t('Clone') }}</b-button>
          </span>
          <span v-else
            class="float-right text-nowrap"
          >
            <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isInterfacesLoading" @click.stop.prevent="addVlanInterface(item)">{{ $t('New VLAN') }}</b-button>
          </span>
        </template>
      </b-table>

      <hr/>

      <pf-form-input :column-label="$t('Default Gateway')"
        form-store-name="formNetwork" form-namespace="gateway"
      />
      <pf-form-input :column-label="$t('Server Hostname')"
        form-store-name="formNetwork" form-namespace="hostname"
      />
    </div>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  columns as columnsInterface
} from '../_config/interface'

export default {
  name: 'interfaces-list',
  components: {
    pfButtonDelete,
    pfEmptyTable,
    pfFormInput,
    pfFormRangeToggle
  },
  data () {
    return {
      interfaces: [] // interfaces from store
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
      this.$store.dispatch('system/getGateway').then((gateway) => {
        this.$store.dispatch(`formNetwork/appendForm`, { gateway })
      })
      this.$store.dispatch('system/getHostname').then((hostname) => {
        this.$store.dispatch(`formNetwork/appendForm`, { hostname })
      })
    },
    /**
     * Interface
     */
    cloneInterface (item) {
      this.$router.push({ name: 'configurator-cloneInterface', params: { id: item.id } })
    },
    removeInterface (item) {
      this.$store.dispatch(`$_interfaces/deleteInterface`, item.id).then(() => {
        this.init() // reload
      })
    },
    addVlanInterface (item) {
      this.$router.push({ name: 'configurator-newInterface', params: { id: item.id } })
    },
    onRowClickInterface (item) {
      this.$router.push({ name: 'configurator-interface', params: { id: item.id } })
    },
    enableInterface (item) {
      return () => { // 'enabled'
        return new Promise((resolve, reject) => {
          this.$store.dispatch(`$_interfaces/upInterface`, item.id).then(() => {
            resolve(true)
          }).catch(() => {
            reject() // resewt
          })
        })
      }
    },
    disableInterface (item) {
      return () => { // 'disabled'
        return new Promise((resolve, reject) => {
          this.$store.dispatch(`$_interfaces/downInterface`, item.id).then(() => {
            resolve(false)
          }).catch(() => {
            reject() // reset
          })
        })
      }
    },
    sortCompareInterface (itemA, itemB, key, sortDesc) {
      if (this.fieldsInterface.filter(field => { return field.key === key && field.sort }).length > 0) {
        return this.fieldsInterface.find(field => { return field.key === key && field.sort }).sort(itemA, itemB, sortDesc, this) // custom sort
      }
      return null // default sort
    },
    save () {
      const { gateway, hostname } = this.$store.getters['formNetwork/$form']
      return Promise.all([
        this.$store.dispatch('system/setGateway', { quiet: true, gateway }).catch(error => {
          // Only show a notification in case of a failure
          const { response: { data: { message = '' } = {} } = {} } = error
          this.$store.dispatch('notification/danger', {
            icon: 'exclamation-triangle',
            url: message,
            message: this.$i18n.t('An error occured while updating the default gateway.')
          })
          throw error
        }),
        this.$store.dispatch('system/setHostname', { quiet: true, hostname }).catch(error => {
          // Only show a notification in case of a failure
          const { response: { data: { message = '' } = {} } = {} } = error
          this.$store.dispatch('notification/danger', {
            icon: 'exclamation-triangle',
            url: message,
            message: this.$i18n.t('An error occured while updating the hostname.')
          })
          throw error
        }),
      ])
    }
  },
  created () {
    this.init()
  }
}
</script>
