<template>
  <div>
    <slot name="pageHeader"></slot>
    <pf-search ref="pfSearch"
      :quick-with-fields="false"
      :quick-placeholder="$t(config.searchPlaceholder)"
      :fields="fields"
      :store="$store"
      :advanced-mode="false"
      :condition="condition"
      @submit-search="onSearch"
      @reset-search="onReset"
    ></pf-search>
    <div class="card-body pt-0">
      <b-row align-h="end" align-v="start">
        <b-col>
          <slot name="buttonAdd"></slot>
        </b-col>
        <b-col cols="auto">
          <b-container fluid>
            <b-row align-v="center">
              <b-form inline class="mb-0">
                <b-form-select class="mb-3 mr-3" size="sm" v-model="pageSizeLimit" :options="[25,50,100,200,500,1000]" :disabled="isLoading"
                  @input="onPageSizeChange" />
              </b-form>
              <b-pagination align="right" :per-page="pageSizeLimit" :total-rows="totalRows" v-model="requestPage" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <slot name="tableHeader"></slot>

      <pf-table-sortable v-if="sortable"
        :items="items"
        :fields="visibleColumns"
        @row-clicked="onRowClick"
        hover
        striped
        @end="sort"
      >
        <slot name="emptySearch" slot="empty" v-bind="{ isLoading }">
          <pf-empty-table :isLoading="isLoading">{{ $t('No results found') }}</pf-empty-table>
        </slot>
        <!-- Proxy all possible column slots ([field]) into pf-table-sortable slots -->
        <template v-for="column in config.columns" :slot="column.key" slot-scope="data">
          <slot :name="column.key" v-bind="data.item">{{ data.item[column.key] }}</slot>
        </template>
      </pf-table-sortable>

      <b-table class="table-clickable" v-else
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        :hover="items.length > 0"
        @sort-changed="onSortingChanged"
        @row-clicked="onRowClick"
        show-empty
        responsive
        fixed
        striped
      >
        <slot name="emptySearch" slot="empty" v-bind="{ isLoading }">
          <pf-empty-table :isLoading="isLoading">{{ $t('No results found') }}</pf-empty-table>
        </slot>
        <!-- Proxy all possible column slots ([field], HEAD_[field], FOOT_[field]) into b-table slots -->
        <template v-for="column in config.columns" :slot="column.key" slot-scope="data">
          <slot :name="column.key" v-bind="data.item">{{ data.item[column.key] }}</slot>
        </template>
        <template v-for="column in config.columns" :slot="'HEAD_' + column.key" slot-scope="data">
          <slot :name="'HEAD_' + column.key">{{ data.label }}</slot>
        </template>
        <template v-for="column in config.columns" :slot="'FOOT_' + column.key" slot-scope="data">
          <slot :name="'FOOT_' + column.key">{{ data.label }}</slot>
        </template>
      </b-table>

    </div>
  </div>
</template>

<script>
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfSearch from '@/components/pfSearch'
import pfTableSortable from '@/components/pfTableSortable'

export default {
  name: 'pf-config-list',
  mixins: [
    pfMixinSearchable
  ],
  components: {
    pfEmptyTable,
    pfSearch,
    pfTableSortable
  },
  props: {
    config: {
      type: Object,
      default: () => ({
        columns: [],
        fields: [],
        rowClickRoute (item, index) { return {} },
        searchPlaceholder: 'Search',
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
      default: () => { return [] }
    },
    sortable: {
      type: Boolean,
      default: false
    }
  },
  computed: {
    fields () {
      return this.config.fields
    },
    columns () {
      return this.config.columns
    },
    searchableOptions () {
      return this.config.searchableOptions
    },
    searchableQuickCondition () {
      return this.config.searchableQuickCondition
    }
  },
  methods: {
    onRowClick (item, index) {
      this.$router.push(this.config.rowClickRoute(item, index))
    },
    resetSearch () {
      this.$refs.pfSearch.onReset()
    },
    submitSearch () {
      this.$refs.pfSearch.onSubmit()
    },
    sort (event) {
      let { oldIndex, newIndex } = event // shifted, not swapped
      // adjust this.items
      let tmp = this.items[oldIndex]
      if (oldIndex > newIndex) {
        // shift down (not swapped)
        for (let i = oldIndex; i > newIndex; i--) {
          this.items[i] = this.items[i - 1]
        }
      } else {
        // shift up (not swapped)
        for (let i = oldIndex; i < newIndex; i++) {
          this.items[i] = this.items[i + 1]
        }
      }
      this.items[newIndex] = tmp
      this.$emit('sort', this.items[newIndex], this.items)
    }
  }
}
</script>
