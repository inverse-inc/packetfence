<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header>
          <h4 class="mb-3" v-t="'PKI Providers'"></h4>
        </b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-dropdown :text="$t('Add PKI Provider')" variant="outline-primary" class="my-2">
          <b-dropdown-item :to="{ name: 'newPkiProvider', params: { providerType: 'packetfence_local' } }">Packetfence Local</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newPkiProvider', params: { providerType: 'packetfence_pki' } }">Packetfence PKI</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newPkiProvider', params: { providerType: 'scep' } }">SCEP PKI</b-dropdown-item>
        </b-dropdown>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No PKI Providers found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <pf-button-delete  v-if="!item.not_deletable" size="sm" variant="outline-danger" :disabled="isLoading" :confirm="$t('Delete PKI Provider?')" @on-delete="remove(item)" reverse/>
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
  pfConfigurationPkiProviderListConfig as config
} from '@/globals/configuration/pfConfigurationPkiProviders'

export default {
  name: 'PkiProvidersList',
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
      this.$router.push({ name: 'clonePkiProvider', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_sources/deletePkiProvider', item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
