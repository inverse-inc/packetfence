<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right"><toggle-button v-model="advancedMode" :sync="true">{{ $t('Advanced') }}</toggle-button></div>
      <h4 class="mb-0">{{ $t('Report') }} <strong v-text="report"></strong></h4>
    </b-card-header>
    <pf-search :fields="fields" :store="$store" storeName="$_reports" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset" @import-search="onImport"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" boundary="viewport" :disabled="isLoading" no-caret>
            <template slot="button-content">
              <icon name="columns" v-b-tooltip.hover.right.d1000 :title="$t('Visible Columns')"></icon>
            </template>
            <b-dropdown-item v-for="column in columns" :key="column.key" @click="toggleColumn(column)" :disabled="column.locked">
              <icon class="position-absolute mt-1" name="thumbtack" v-show="column.visible" v-if="column.locked"></icon>
              <icon class="position-absolute mt-1" name="check" v-show="column.visible" v-else></icon>
              <span class="ml-4">{{column.label}}</span>
            </b-dropdown-item>
          </b-dropdown>
        </b-col>
        <b-col cols="auto">
          <b-container fluid>
            <b-row align-v="center">
              <b-form inline class="mb-0">
                <b-form-select class="mb-3 mr-3" size="sm" v-model="pageSizeLimit" :options="[10,25,50,100]" :disabled="isLoading"
                  @input="onPageSizeChange" />
              </b-form>
              <b-pagination align="right" v-model="requestPage" :per-page="pageSizeLimit" :total-rows="totalRows" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table stacked="sm" :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" responsive="true" hover no-local-sorting v-model="tableValues"></b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import pfMixinSearchable from '@/components/pfMixinSearchable'

export default {
  name: 'ReportTable',
  mixins: [
    pfMixinSearchable
  ],
  props: {
    pfMixinSearchableOptions: {
      type: Object,
      default: {
        searchApiEndpoint: undefined, // overwritten by router
        defaultSortKeys: ['mac'],
        defaultSearchCondition: { op: 'and', values: [{ op: 'or', values: [{ field: 'mac', op: 'equals', value: null }] }] },
        defaultRoute: { name: 'table' }
      }
    },
    report: String, // from router
    tableValues: {
      type: Array,
      default: []
    }
  },
  data () {
    return {
      /**
       *  Fields on which a search can be defined.
       *  The names must match the database schema.
       *  The keys must conform to the format of the b-form-select's options property.
       */
      fields: [ // keys match with b-form-select
        {
          value: 'mac',
          text: this.$i18n.t('MAC Address'),
          types: [conditionType.SUBSTRING]
        }
      ],
      /**
       * The columns that can be displayed in the results table.
       */
      columns: [
        {
          key: 'mac',
          label: this.$i18n.t('MAC Address'),
          sortable: true,
          visible: true
        }
      ],
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 10
    }
  },
  beforeRouteUpdate (to, from, next) {
    this.pfMixinSearchableOptions.searchApiEndpoint = `reports/${to.params.report}`
    next()
  },
  beforeRouteEnter (to, from, next) {
    next(vm => {
      vm.pfMixinSearchableOptions.searchApiEndpoint = `reports/${to.params.report}`
    })
  }
}
</script>
