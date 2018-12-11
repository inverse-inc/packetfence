<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
      :isLoading="isLoading"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Billing Tiers'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newBillingTier' }">{{ $t('Add Billing Tier') }}</b-button>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No billing tiers found') }}</pf-empty-table>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationBillingTiersListColumns as columns,
  pfConfigurationBillingTiersListFields as fields
} from '@/globals/pfConfigurationBillingTiers'

export default {
  name: 'BillingTiersList',
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
          return { name: 'billing_tier', params: { id: item.id } }
        },
        searchPlaceholder: this.$i18n.t('Search by identifier, name or description'),
        searchableOptions: {
          searchApiEndpoint: 'config/billing_tiers',
          defaultSortKeys: ['id'],
          defaultSearchCondition: {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: null },
                { field: 'name', op: 'contains', value: null },
                { field: 'description', op: 'contains', value: null }
              ]
            }]
          },
          defaultRoute: { name: 'configuration/billing_tiers' }
        },
        searchableQuickCondition: (quickCondition) => {
          return {
            op: 'and',
            values: [
              {
                op: 'or',
                values: [
                  { field: 'id', op: 'contains', value: quickCondition },
                  { field: 'name', op: 'contains', value: quickCondition },
                  { field: 'description', op: 'contains', value: quickCondition }
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
