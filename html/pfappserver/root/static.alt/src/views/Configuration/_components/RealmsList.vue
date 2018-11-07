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
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export default {
  name: 'RealmsList',
  components: {
    pfConfigList,
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
          },
          {
            key: 'portal_strip_username',
            label: this.$i18n.t('Strip Portal'),
            sortable: true,
            visible: true
          },
          {
            key: 'admin_strip_username',
            label: this.$i18n.t('Strip Admin'),
            sortable: true,
            visible: true
          },
          {
            key: 'radius_strip_username',
            label: this.$i18n.t('Strip RADIUS'),
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
