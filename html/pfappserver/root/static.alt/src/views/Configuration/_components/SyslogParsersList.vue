<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0" v-t="'Syslog Parsers'"></h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-dropdown :text="$t('New Syslog Parser')" variant="outline-primary">
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'dhcp' } }">DHCP</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'fortianalyser' } }">FortiAnalyzer</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'nexpose' } }">Nexpose</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'regex' } }">Regex</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'security_onion' } }">Security Onion</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'snort' } }">Snort</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'suricata' } }">Suricata</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newSyslogParser', params: { syslogParserType: 'suricata_md5' } }">Suricata MD5</b-dropdown-item>
        </b-dropdown>
        <pf-button-service service="pfdetect" class="ml-1" restart start stop :disabled="isLoading"></pf-button-service>
        <pf-button-service service="pfqueue" class="ml-1" restart start stop :disabled="isLoading"></pf-button-service>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No syslog parsers found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Syslog Parser?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
      <template v-slot:cell(status)="item">
        <pf-form-range-toggle
          v-model="item.status"
          :values="{ checked: 'enabled', unchecked: 'disabled' }"
          :icons="{ checked: 'check', unchecked: 'times' }"
          :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
          :right-labels="{ checked: $t('Enabled'), unchecked: $t('Disabled') }"
          :lazy="{ checked: enable(item), unchecked: disable(item) }"
          @click.stop.prevent
        />
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonService from '@/components/pfButtonService'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import { config } from '../_config/syslogParser'

export default {
  name: 'syslog-parsers-list',
  components: {
    pfButtonDelete,
    pfButtonService,
    pfConfigList,
    pfEmptyTable,
    pfFormRangeToggle
  },
  data () {
    return {
      config: config(this) // ../_config/syslogParser
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_syslog_parsers/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneSyslogParser', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_syslog_parsers/deleteSyslogParser', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    },
    enable (item) {
      return () => { // 'enabled'
        return new Promise((resolve, reject) => {
          this.$store.dispatch('$_syslog_parsers/enableSyslogParser', item).then(() => {
            this.$store.dispatch(`${this.$refs.pfConfigList.searchableStoreName}/updateItem`, { key: 'id', id: item.id, prop: 'status', data: 'enabled' }).then(() => {
              resolve('enabled')
            })
          }).catch(() => {
            reject() // reset
          })
        })
      }
    },
    disable (item) {
      return () => { // 'disabled'
        return new Promise((resolve, reject) => {
          this.$store.dispatch('$_syslog_parsers/disableSyslogParser', item).then(() => {
            this.$store.dispatch(`${this.$refs.pfConfigList.searchableStoreName}/updateItem`, { key: 'id', id: item.id, prop: 'status', data: 'disabled' }).then(() => {
              resolve('disabled')
            })
          }).catch(() => {
            reject() // reset
          })
        })
      }
    }
  }
}
</script>
