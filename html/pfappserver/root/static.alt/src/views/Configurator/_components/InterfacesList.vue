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

      <pf-form-row>
        <pf-button
          v-if="managementTypeCount === 0"
          variant="outline-primary"
          class="float-right"
          @click="detectManagementInterface()">{{ $t('Detect Management Interface') }}</pf-button>
      </pf-form-row>

      <hr/>

      <pf-form-input :column-label="$t('Default Gateway')"
        form-store-name="formNetwork" form-namespace="gateway"
      />
      <pf-form-input :column-label="$t('Server Hostname')" :text="rebootAlert"
        form-store-name="formNetwork" form-namespace="hostname"
      />
      <pf-form-chosen :column-label="$t('DNS Servers')"
        :multiple="true" :taggable="true"
        :tag-placeholder="$t('Click to add host')"
        @tag="addDnsServer"
        form-store-name="formNetwork" form-namespace="dns_servers"
      />
    </div>
  </b-card>
</template>

<script>
import pfButton from '@/components/pfButton'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormRow from '@/components/pfFormRow'
import {
  columns as columnsInterface
} from '../_config/interface'
import network from '@/utils/network'

export default {
  name: 'interfaces-list',
  components: {
    pfButton,
    pfButtonDelete,
    pfEmptyTable,
    pfFormChosen,
    pfFormInput,
    pfFormRangeToggle,
    pfFormRow
  },
  data () {
    return {
      interfaces: [] // interfaces from store
    }
  },
  computed: {
    form () {
      return this.$store.getters[`formNetwork/$form`]
    },
    hostname () {
      return this.$store.getters[`formNetwork/$formNS`]('hostname')
    },
    gateway () {
      return this.$store.getters[`formNetwork/$formNS`]('gateway')
    },
    rebootAlert () {
      if (this.isInterfacesLoading || typeof this.hostname  !== 'string' || this.$store.state.system.hostname === this.hostname) {
        return null
      } else {
        return `<span class="text-warning">${this.$i18n.t('Please reboot the server at the end of the configuration wizard to apply changes.')}</span>`
      }
    },
    isInterfacesLoading () {
      return this.$store.getters[`$_interfaces/isLoading`]
    },
    fieldsInterface () {
      return columnsInterface
    },
    managementTypeCount () {
      return this.interfaces.filter(i => i.type === 'management').length
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
        this.$watch('managementTypeCount', () => {
            this.$set(this.form, 'management_type', this.managementTypeCount)
          },
          { immediate: true }
        )
      })
      this.$store.dispatch('system/getHostname').then((hostname) => {
        this.$store.dispatch(`formNetwork/appendForm`, { hostname })
      })
      this.$store.dispatch('system/getDnsServers').then((dns_servers) => {
        this.$store.dispatch(`formNetwork/appendForm`, { dns_servers })
      })
    },
    detectManagementInterface () {
      if (this.managementTypeCount === 0) {
        // No interface is of type management -- force one
        let management_interface = this.interfaces.find(i => {
          return i.network && i.netmask && network.ipv4InSubnet(this.gateway, network.ipv4NetmaskToSubnet(i.network, i.netmask))
        })
        if (!management_interface) {
          management_interface = this.interfaces.find(i => {
            return i.address && i.address.length > 0
          })
        }
        if (management_interface) {
          management_interface.type = 'management'
          this.$store.dispatch('$_interfaces/updateInterface', management_interface)
        }
      }
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
    /**
     * DNS Servers
     */
    addDnsServer (value) {
      this.form.dns_servers.push(value)
    },
    save () {
      const { gateway, hostname, dns_servers } = this.$store.getters['formNetwork/$form']
      return Promise.all([
        this.$store.dispatch('system/getGateway').then((initialGateway) => {
          if (initialGateway === gateway) {
            return Promise.resolve() // no change
          } else {
            return this.$store.dispatch('system/setGateway', { quiet: true, gateway })
          }
        }).catch(error => {
          // Only show a notification in case of a failure
          const { response: { data: { message = '' } = {} } = {} } = error
          this.$store.dispatch('notification/danger', {
            icon: 'exclamation-triangle',
            url: message,
            message: this.$i18n.t('An error occured while updating the default gateway.')
          })
          throw error
        }),
        this.$store.dispatch('system/getHostname').then((initialHostname) => {
          if (initialHostname === hostname) {
            return Promise.resolve()
          } else {
            return this.$store.dispatch('system/setHostname', { quiet: true, hostname })
          }
        }).catch(error => {
          // Only show a notification in case of a failure
          const { response: { data: { message = '' } = {} } = {} } = error
          this.$store.dispatch('notification/danger', {
            icon: 'exclamation-triangle',
            url: message,
            message: this.$i18n.t('An error occured while updating the hostname.')
          })
          throw error
        }),
        this.$store.dispatch('system/setDnsServers', { quiet: true, dns_servers }).catch(error => {
          // Only show a notification in case of a failure
          const { response: { data: { message = '' } = {} } = {} } = error
          this.$store.dispatch('notification/danger', {
            icon: 'exclamation-triangle',
            url: message,
            message: this.$i18n.t('An error occured while updating the DNS servers.')
          })
          throw error
        })
      ])
    }
  },
  created () {
    this.init()
  }
}
</script>
