<template>
  <div>
    <pf-config-list
      :config="config"
      :isLoading="isLoading"
    >
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newRealm' }">{{ $t('Add Realm') }}</b-button>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No realms found') }}</pf-empty-table>
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
} from '@/globals/pfConfigurationRealms'

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
          defaultRoute: { name: 'configuration/roles' }
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
  }
}
</script>
