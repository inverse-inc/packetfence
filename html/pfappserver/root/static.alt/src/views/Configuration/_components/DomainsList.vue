<template>
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
</template>

<script>
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationDomainsListColumns as columns,
  pfConfigurationDomainsListFields as fields
} from '@/globals/pfConfigurationDomains'

export default {
  name: 'DomainsList',
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
