<template>
  <div>
    <config-page-list
      :config="config"
      :isLoading="isLoading"
    >
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newDomain' }">{{ $t('Add Domain') }}</b-button>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No domains found') }}</pf-empty-table>
      </template>
    </config-page-list>
  </div>
</template>

<script>
import ConfigPageList from './_lib/ConfigPageList'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import pfEmptyTable from '@/components/pfEmptyTable'

export default {
  name: 'DomainsList',
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
