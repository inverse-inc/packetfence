<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <h4 class="mb-0" v-t="config.pageTitle"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by name or description"
      :fields="fields" :store="$store" :advanced-mode="false" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset"></pf-search>
    <div class="card-body">
      <b-row align-h="end" align-v="start">
        <b-col>
          <b-button variant="outline-primary" :to="config.buttonAddRoute">{{ config.buttonAddLabel }}</b-button>
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
        <template slot="empty">
          <pf-empty-table :isLoading="isLoading">{{ config.emptyTableText }}</pf-empty-table>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfProgress from '@/components/pfProgress'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfSearch from '@/components/pfSearch'

export default {
  name: 'BaseList',
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
      default: () => ({})
    },
    tableValues: {
      type: Array,
      default: () => []
    }
  },
  data () {
    return {
      config: {
        pageTitle: 'config.pageTitle',
        buttonAddLabel: 'config.buttonAddLabel',
        buttonAddRoute: {},
        emptyTableText: 'config.emptyTable'
      },
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'id',
          text: 'Name',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'notes',
          text: 'Description',
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
              { field: 'notes', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    },
    onRowClick (item, index) {
      this.$router.push({ name: 'role', params: { id: item.id } })
    }
  }
}
</script>
