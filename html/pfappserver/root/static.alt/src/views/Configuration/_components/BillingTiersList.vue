<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Billing Tiers'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newBillingTier' }">{{ $t('Add Billing Tier') }}</b-button>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No billing tiers found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <pf-button-delete  v-if="!item.not_deletable" size="sm" variant="outline-danger" :disabled="isLoading" :confirm="$t('Delete Billing Tier?')" @on-delete="remove(item)" reverse/>
        </span>
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
} from '@/globals/configuration/pfConfigurationBillingTiers'

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
          defaultRoute: { name: 'billing_tiers' }
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
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneBillingTier', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_billing_tiers/deleteBillingTier', item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
