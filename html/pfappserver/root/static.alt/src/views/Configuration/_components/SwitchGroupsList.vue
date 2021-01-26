<template>
  <pf-config-list
    ref="pfConfigList"
    :config="config"
  >
    <template v-slot:buttonAdd>
      <b-button variant="outline-primary" :to="{ name: 'newSwitchGroup' }">{{ $t('New Switch Group') }}</b-button>
    </template>
    <template v-slot:emptySearch="state">
      <pf-empty-table :isLoading="state.isLoading">{{ $t('No switch groups found') }}</pf-empty-table>
    </template>
    <template v-slot:cell(buttons)="item">
      <span class="float-right text-nowrap">
        <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Switch Group?')" @on-delete="remove(item)" reverse/>
        <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
      </span>
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/switchGroup'

export default {
  name: 'switch-groups-list',
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
  computed: {
    isLoading () {
      return this.$store.getters['$_switch_groups/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneSwitchGroup', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_switch_groups/deleteSwitchGroup', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    }
  }
}
</script>
