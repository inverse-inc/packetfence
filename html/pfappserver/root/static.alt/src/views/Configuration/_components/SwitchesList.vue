<template>
  <pf-config-list
    :config="config"
  >
    <template slot="buttonAdd">
      <b-dropdown :text="$t('Add Switch')" variant="outline-primary" class="my-2">
        <b-dropdown-header class="text-secondary">{{ $t('To group') }}</b-dropdown-header>
          <b-dropdown-item :to="{ name: 'newSwitch', params: { switchGroup: 'default' } }">{{ $t('default') }}</b-dropdown-item>
          <b-dropdown-item v-for="(switchGroup, index) in switches" :key="index"
            :to="{ name: 'newSwitch', params: { switchGroup: switchGroup.id } }">{{ switchGroup.id }}</b-dropdown-item>
      </b-dropdown>
    </template>
    <template slot="emptySearch" slot-scope="state">
      <pf-empty-table :isLoading="state.isLoading">{{ $t('No switches found') }}</pf-empty-table>
    </template>
    <template slot="buttons" slot-scope="item">
      <span class="float-right text-nowrap">
        <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Switch?')" @on-delete="remove(item)" reverse/>
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
  pfConfigurationSwitchesListConfig as config
} from '@/globals/configuration/pfConfigurationSwitches'

export default {
  name: 'SwitchesList',
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
      switches: [], // all switches
      config: config(this)
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneSwitch', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteSwitch`, item.id).then(response => {
        this.$router.go() // reload
      })
    }
  },
  created () {
    this.$store.dispatch('$_switch_groups/all').then(data => {
      this.switches = data
    })
  }
}
</script>
