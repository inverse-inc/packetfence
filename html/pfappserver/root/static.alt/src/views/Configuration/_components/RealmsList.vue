<template>
  <div>
    <pf-config-list
      :config="config"
    >
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newRealm' }">{{ $t('Add Realm') }}</b-button>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No realms found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <pf-button-delete  v-if="!item.not_deletable" size="sm" variant="outline-danger" :disabled="isLoading" :confirm="$t('Delete Realm?')" @on-delete="remove(item)" reverse/>
        </span>
      </template>
    </pf-config-list>
  </div>
</template>

<script>
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationRealmsListColumns as columns,
  pfConfigurationRealmsListFields as fields
} from '@/globals/configuration/pfConfigurationRealms'

export default {
  name: 'RealmsList',
  components: {
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: {
        columns: columns,
        fields: fields,
        rowClickRoute (item, index) {
          return { name: 'realm', params: { id: item.id } }
        },
        searchPlaceholder: this.$i18n.t('Search by name'),
        searchableOptions: {
          searchApiEndpoint: 'config/realms',
          defaultSortKeys: ['id'],
          defaultSearchCondition: {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: null }
              ]
            }]
          },
          defaultRoute: { name: 'realms' }
        },
        searchableQuickCondition: (quickCondition) => {
          return {
            op: 'and',
            values: [
              {
                op: 'or',
                values: [
                  { field: 'id', op: 'contains', value: quickCondition }
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
      this.$router.push({ name: 'cloneRealm', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_realms/deleteRealm', item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
