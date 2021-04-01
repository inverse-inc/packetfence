<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('WMI Rules') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_wmi_rules_definition" />
          </h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newWmiRule' }">{{ $t('New WMI Rule') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :is-loading="state.isLoading">{{ $t('No WMI rules found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(on_tab)="item">
        <icon name="circle" :class="{ 'text-success': item.on_tab === '1', 'text-danger': item.on_tab !== '1' }"
          v-b-tooltip.hover.left.d300 :title="$t(item.on_tab)"></icon>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete WMI Rule?')" @on-delete="remove(item)" reverse/>
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
import { config } from '../_config/wmiRule'

export default {
  name: 'wmi-rules-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this) // ../_config/wmiRule
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_wmi_rules/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneWmiRule', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_wmi_rules/deleteWmiRule', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    }
  }
}
</script>
