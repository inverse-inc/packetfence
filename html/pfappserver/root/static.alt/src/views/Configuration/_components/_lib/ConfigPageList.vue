<template>
  <div>
    <pf-progress :active="isLoading"></pf-progress>
    <slot name="pageHeader"></slot>
    <pf-search :quick-with-fields="false" :quick-placeholder="config.searchPlaceholder"
      :fields="fields" :store="$store" :advanced-mode="false" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset"></pf-search>
    <div class="card-body">
      <b-row align-h="end" align-v="start">
        <b-col>
          <slot name="buttonAdd">
            <b-button variant="outline-primary" :to="{}">{{ $t('Add') }}</b-button>
          </slot>
        </b-col>
        <b-col cols="auto">
          <b-container fluid>
            <b-row align-v="center">
              <b-form inline class="mb-0">
                <b-form-select class="mb-3 mr-3" size="sm" v-model="pageSizeLimit" :options="[10,25,50,100]" :disabled="isLoading"
                  @input="onPageSizeChange" />
              </b-form>
              <b-pagination align="right" :per-page="pageSizeLimit" :total-rows="totalRows" v-model="requestPage" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table class="table-clickable"
        :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick"
        show-empty responsive hover no-local-sorting>
        <slot name="emptySearch" slot="empty">
          <pf-empty-table :isLoading="isLoading">{{ $t('No results found') }}</pf-empty-table>
        </slot>
      </b-table>
    </div>
  </div>
</template>

<script>
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfProgress from '@/components/pfProgress'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfSearch from '@/components/pfSearch'

export default {
  name: 'ConfigPageList',
  mixins: [
    pfMixinSearchable
  ],
  components: {
    pfProgress,
    pfEmptyTable,
    pfSearch
  },
  props: {
    config: {
      type: Object,
      default: () => ({
        columns: [],
        fields: [],
        rowClickRoute (item, index) {
          return {}
        },
        searchPlaceholder: this.$i18n.t('Search'),
        searchableOptions: {
          searchApiEndpoint: null,
          defaultSortKeys: [],
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
          defaultRoute: { name: null }
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
      })
    },
    tableValues: {
      type: Array,
      default: () => []
    }
  },
  data () {
    return {}
  },
  computed: {
    fields () {
      return this.config.fields
    },
    columns () {
      return this.config.columns
    },
    pfMixinSearchableOptions () {
      return this.config.searchableOptions
    },
    pfMixinSearchableQuickCondition () {
      return this.config.searchableQuickCondition
    }
  },
  methods: {
    onRowClick (item, index) {
      this.$router.push(this.config.rowClickRoute(item, index))
    }
  }
}
</script>
