<template>
  <div>
    <pf-config-list
      :config="config"
      :isLoading="isLoading"
    >
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newDomain' }">{{ $t('Add Domain') }}</b-button>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No domains found') }}</pf-empty-table>
      </template>
    </pf-config-list>
  </div>
</template>

<script>
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export default {
  name: 'DomainsList',
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
            key: 'workgroup',
            label: this.$i18n.t('Workgroup'),
            sortable: true,
            visible: true
          }
        ],
        fields: [
          {
            value: 'id',
            text: 'Name',
            types: [conditionType.SUBSTRING]
          },
          {
            value: 'workgroup',
            text: 'Workgroup',
            types: [conditionType.SUBSTRING]
          }
        ],
        rowClickRoute (item, index) {
          return { name: 'domain', params: { id: item.id } }
        },
        searchPlaceholder: this.$i18n.t('Search by name or workgroup'),
        searchableOptions: {
          searchApiEndpoint: 'config/domains',
          defaultSortKeys: ['id'],
          defaultSearchCondition: {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: null },
                { field: 'workgroup', op: 'contains', value: null }
              ]
            }]
          },
          defaultRoute: { name: 'configuration/domains' }
        },
        searchableQuickCondition: (quickCondition) => {
          return {
            op: 'and',
            values: [
              {
                op: 'or',
                values: [
                  { field: 'id', op: 'contains', value: quickCondition },
                  { field: 'workgroup', op: 'contains', value: quickCondition }
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
