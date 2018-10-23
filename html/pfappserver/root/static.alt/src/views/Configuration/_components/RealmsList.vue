<template>
  <div>
    <config-page-list
      :config="config"
      :isLoading="isLoading"
    >
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newRealm' }">{{ $t('Add Realm') }}</b-button>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No realms found') }}</pf-empty-table>
      </template>
    </config-page-list>
  </div>
</template>

<script>
import ConfigPageList from './_lib/ConfigPageList'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import pfEmptyTable from '@/components/pfEmptyTable'

export default {
  name: 'RealmsList',
  components: {
    ConfigPageList,
    pfEmptyTable
  },
  data () {
    return {
      config: {
        columns: [
          {
            key: 'id',
            label: this.$i18n.t('Name'),
            sortable: true,
            visible: true
          }
        ],
        fields: [
          {
            value: 'id',
            text: 'Name',
            types: [conditionType.SUBSTRING]
          }
        ],
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
