<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Scan Engines'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-dropdown :text="$t('New Scan Engine')" variant="outline-primary">
          <b-dropdown-item :to="{ name: 'newScanEngine', params: { scanType: 'nessus' } }">Nessus</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newScanEngine', params: { scanType: 'nessus6' } }">Nessus 6</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newScanEngine', params: { scanType: 'openvas' } }">OpenVAS</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newScanEngine', params: { scanType: 'rapid7' } }">Rapid7</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newScanEngine', params: { scanType: 'wmi' } }">WMI</b-dropdown-item>
        </b-dropdown>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No scan engines found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Scan Engine?')" @on-delete="remove(item)" reverse/>
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
  pfConfigurationScanEngineListConfig as config
} from '@/globals/configuration/pfConfigurationScans'

export default {
  name: 'ProfilingDevicesList',
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
      scanEngines: [], // all scan engines
      config: config(this)
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneScanEngine', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteScanEngine`, item.id).then(response => {
        this.$router.go() // reload
      })
    }
  },
  created () {
    this.$store.dispatch(`${this.storeName}/allScanEngines`).then(data => {
      this.scanEngines = data
    })
  }
}
</script>
