<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
      :isLoading="isLoading"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Roles'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newRole' }">{{ $t('Add Role') }}</b-button>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No roles found') }}</pf-empty-table>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export default {
  name: 'RolesList',
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
            key: 'notes',
            label: this.$i18n.t('Description'),
            sortable: true,
            visible: true
          },
          {
            key: 'max_nodes_per_pid',
            label: this.$i18n.t('Max nodes per user'),
            sortable: true,
            visible: true
          }
        ],
        fields: [
          {
            value: 'id',
            text: this.$i18n.t('Name'),
            types: [conditionType.SUBSTRING]
          },
          {
            value: 'notes',
            text: this.$i18n.t('Description'),
            types: [conditionType.SUBSTRING]
          }
        ],
        rowClickRoute (item, index) {
          return { name: 'role', params: { id: item.id } }
        },
        searchPlaceholder: this.$i18n.t('Search by name or description'),
        searchableOptions: {
          searchApiEndpoint: 'config/roles',
          defaultSortKeys: ['id'],
          defaultSearchCondition: {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: null },
                { field: 'notes', op: 'contains', value: null }
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
                  { field: 'id', op: 'contains', value: quickCondition },
                  { field: 'notes', op: 'contains', value: quickCondition }
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
