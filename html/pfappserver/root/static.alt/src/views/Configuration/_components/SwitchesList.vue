<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
      :isLoading="isLoading"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Switches'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-dropdown :text="$t('Add Switch')" variant="outline-primary" class="my-2">
          <b-dropdown-header class="text-secondary">{{ $t('To group') }}</b-dropdown-header>
            <b-dropdown-item :to="{ name: 'newSwitch', params: { switchGroup: 'default' } }">{{ $t('default') }}</b-dropdown-item>
            <b-dropdown-item v-for="(switchGroup, index) in switchGroups" :key="index"
              :to="{ name: 'newSwitch', params: { switchGroup: switchGroup.id } }">{{ switchGroup.id }}</b-dropdown-item>
        </b-dropdown>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No switches found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <pf-button-delete  v-if="!item.not_deletable" size="sm" variant="outline-danger" :disabled="isLoading" :confirm="$t('Delete Switch?')" @on-delete="remove(item)" reverse/>
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
  pfConfigurationSwitchesListColumns as columns,
  pfConfigurationSwitchesListFields as fields
} from '@/globals/pfConfigurationSwitches'

export default {
  name: 'SwitchesList',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      switchGroups: [], // all switch groups
      config: {
        columns: columns,
        fields: fields,
        rowClickRoute (item, index) {
          return { name: 'switch', params: { id: item.id } }
        },
        searchPlaceholder: this.$i18n.t('Search by identifier or description'),
        searchableOptions: {
          searchApiEndpoint: 'config/switches',
          defaultSortKeys: ['id'],
          defaultSearchCondition: {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: null },
                { field: 'description', op: 'contains', value: null },
                { field: 'type', op: 'contains', value: null },
                { field: 'mode', op: 'contains', value: null }
              ]
            }]
          },
          defaultRoute: { name: 'switches' }
        },
        searchableQuickCondition: (quickCondition) => {
          return {
            op: 'and',
            values: [
              {
                op: 'or',
                values: [
                  { field: 'id', op: 'contains', value: quickCondition },
                  { field: 'description', op: 'contains', value: quickCondition },
                  { field: 'type', op: 'contains', value: quickCondition },
                  { field: 'mode', op: 'contains', value: quickCondition }
                ]
              }
            ]
          }
        }
      }
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneSwitch', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_switches/deleteSwitch', item.id).then(response => {
        this.$router.go() // reload
      })
    }
  },
  created () {
    this.$store.dispatch('$_switch_groups/all').then(data => {
      this.switchGroups = data
    })
  }
}
</script>
