<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('Scan Engines') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_scanner_definition" />
          </h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-dropdown :text="$t('New Scan Engine')" variant="outline-primary">
          <b-dropdown-item :to="{ name: 'newScanEngine', params: { scanType: 'nessus' } }">Nessus</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newScanEngine', params: { scanType: 'nessus6' } }">Nessus 6</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newScanEngine', params: { scanType: 'openvas' } }">OpenVAS</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newScanEngine', params: { scanType: 'rapid7' } }">Rapid7</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newScanEngine', params: { scanType: 'wmi' } }">WMI</b-dropdown-item>
        </b-dropdown>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No scan engines found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
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
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/scanEngine'

export default {
  name: 'scan-engines-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this) // ../_config/scanEngine
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneScanEngine', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_scans/deleteScanEngine', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    }
  }
}
</script>
