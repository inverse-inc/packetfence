<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0" v-t="'Syslog Entries'"></h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newSyslogForwarder', params: { syslogForwarderType: 'server' } }">{{ $t('New Syslog Entry') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No syslog entries found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Syslog Entry?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
      <template v-slot:cell(status)="item">
        <icon name="circle" :class="{ 'text-success': item.status === 'enabled', 'text-danger': item.status === 'disabled' }"
          v-b-tooltip.hover.left.d300 :title="$t(item.status)"></icon>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/syslogForwarder'

export default {
  name: 'syslog-forwarders-list',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this) // ../_config/syslogForwarder
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_syslog_forwarders/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneSyslogForwarder', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_syslog_forwarders/deleteSyslogForwarder', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    }
  }
}
</script>
