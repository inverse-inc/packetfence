<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header>
          <h4 class="mb-3" v-t="'Syslog Parsers'"></h4>
        </b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-dropdown :text="$t('Add Syslog Parser')" variant="outline-primary" class="my-2">
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'dhcp' } }">DHCP</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'fortianalyser' } }">FortiAnalyzer</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'nexpose' } }">Nexpose</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'regex' } }">regex</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'security_onion' } }">Security Onion</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'snort' } }">Snort</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'suricata' } }">Suricata</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'suricata_md5' } }">Suricata MD5</b-dropdown-item>
        </b-dropdown>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No syslog parsers found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Syslog Parser?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
      <template slot="status" slot-scope="data">
        <icon name="circle" :class="{ 'text-success': data.status === 'enabled', 'text-danger': data.status === 'disabled' }"
          v-b-tooltip.hover.left.d300 :title="$t(data.status)"></icon>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationSyslogParsersListConfig as config
} from '@/globals/configuration/pfConfigurationSyslogParsers'

export default {
  name: 'SyslogParsersList',
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
      this.$router.push({ name: 'cloneSyslogParser', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_syslog_parsers/deleteSyslogParser', item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
