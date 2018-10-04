<template>
  <div>
    <pf-progress :active="isLoading"></pf-progress>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by name or workgroup"
      :fields="fields" :store="$store" :advanced-mode="false" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset"></pf-search>
    <div class="card-body">
      <b-row align-h="end" align-v="start">
        <b-col>
          <b-button variant="outline-primary" :to="{ name: 'newDomain' }">{{ $t('Add Domain') }}</b-button>
        </b-col>
        <b-col cols="auto">
          <b-container fluid>
            <b-row align-v="center">
              <b-form inline class="mb-0">
                <b-form-select class="mb-3 mr-3" size="sm" v-model="pageSizeLimit"
                  :options="[10,25,50,100]" :disabled="isLoading"
                  @input="onPageSizeChange" />
              </b-form>
              <b-pagination align="right" v-model="requestPage"
                :per-page="pageSizeLimit" :total-rows="totalRows" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table class="table-clickable"
        :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick"
        show-empty responsive hover no-local-sorting>
      <template slot="empty">
        <pf-empty-table :isLoading="isLoading">{{ $t('No domain found') }}</pf-empty-table>
      </template>
      </b-table>
    </div>
  </div>
</template>

<script>
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfProgress from '@/components/pfProgress'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfSearch from '@/components/pfSearch'

export default {
  name: 'DomainsList',
  mixins: [
    pfMixinSearchable
  ],
  components: {
    pfProgress,
    pfEmptyTable,
    pfSearch
  },
  props: {
    pfMixinSearchableOptions: {
      type: Object,
      default: () => ({
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
      })
    },
    tableValues: {
      type: Array,
      default: () => []
    }
  },
  data () {
    return {
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
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
      ]
    }
  },
  methods: {
    pfMixinSearchableQuickCondition (quickCondition) {
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
    },
    onRowClick (item, index) {
      this.$router.push({ name: 'domain', params: { id: item.id } })
    }
  }
}
</script>
