<template>
  <pf-config-list
    :config="config"
  >
    <template slot="buttonAdd">
      <b-button variant="outline-primary" :to="{ name: 'newSwitchGroup' }">{{ $t('Add Switch Group') }}</b-button>
    </template>
    <template slot="emptySearch" slot-scope="state">
      <pf-empty-table :isLoading="state.isLoading">{{ $t('No switch groups found') }}</pf-empty-table>
    </template>
    <template slot="buttons" slot-scope="item">
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
import {
  pfConfigurationSwitchGroupsListConfig as config
} from '@/globals/configuration/pfConfigurationSwitchGroups'

export default {
  name: 'SwitchGroupsList',
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
      this.$router.push({ name: 'cloneSwitchGroup', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_switch_groups/deleteSwitchGroup', item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
