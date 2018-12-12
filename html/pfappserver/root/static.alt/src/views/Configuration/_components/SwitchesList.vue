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
        <b-button variant="outline-primary" :to="{ name: 'newSwitch' }">{{ $t('Add Switch') }}</b-button>
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
          defaultRoute: { name: 'configuration/switches' }
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
  }
}
</script>

<style lang="scss">
#source-add-container div[role="menu"] {
  overflow-x: hidden;
  overflow-y: scroll;
  max-height: 50vh;
}
</style>
