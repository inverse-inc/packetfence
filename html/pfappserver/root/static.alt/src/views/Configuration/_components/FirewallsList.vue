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
        <b-dropdown :text="$t('Add Firewall')" variant="outline-primary" class="my-2">
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'BarracudaNG' } }">BarracudaNG</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'Checkpoint' } }">Checkpoint</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'FortiGate' } }">FortiGate</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'Iboss' } }">Iboss</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'JuniperSRX' } }">JuniperSRX</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'PaloAlto' } }">PaloAlto</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'WatchGuard' } }">WatchGuard</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newFirewall', params: { firewallType: 'JSONRPC' } }">JSONRPC</b-dropdown-item>
        </b-dropdown>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No firewalls found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <pf-button-delete  v-if="!item.not_deletable" size="sm" variant="outline-danger" :disabled="isLoading" :confirm="$t('Delete Firewall?')" @on-delete="remove(item)" reverse/>
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
  pfConfigurationFirewallListConfig as config
} from '@/globals/configuration/pfConfigurationFirewalls'

export default {
  name: 'FirewallsList',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
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
      this.$store.dispatch('$_sources/deleteFirewall', item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
