<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header>
          <h4 class="mb-3" v-t="'Firewall SSO'"></h4>
        </b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-dropdown :text="$t('New Firewall')" variant="outline-primary">
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'BarracudaNG' } }">BarracudaNG</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'Checkpoint' } }">Checkpoint</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'FortiGate' } }">FortiGate</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'Iboss' } }">Iboss</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'JuniperSRX' } }">JuniperSRX</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'PaloAlto' } }">PaloAlto</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'WatchGuard' } }">WatchGuard</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'JSONRPC' } }">JSONRPC</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'LightSpeedRocket' } }">LightSpeedRocket</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'SmoothWall' } }">SmoothWall</b-dropdown-item>
        </b-dropdown>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No firewalls found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Firewall?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationFirewallsListConfig as config
} from '@/globals/configuration/pfConfigurationFirewalls'

export default {
  name: 'firewalls-list',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
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
      config: config(this)
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneFirewall', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteFirewall`, item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
