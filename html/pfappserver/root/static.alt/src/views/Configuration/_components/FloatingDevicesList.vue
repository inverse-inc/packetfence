<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <h4 class="mb-0" v-t="'Floating Devices'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by MAC or IP address"
      :fields="fields" :advanced-mode="false" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset"></pf-search>
    <div class="card-body">
      <b-row align-h="end" align-v="center">
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
          <pf-empty-table :isLoading="isLoading">{{ $t('No floating device found') }}</pf-empty-table>
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
  name: 'FloatingDevicesList',
  mixins: [
    pfMixinSearchable
  ],
  components: {
    'pf-progress': pfProgress,
    'pf-empty-table': pfEmptyTable,
    'pf-search': pfSearch
  },
  props: {
    pfMixinSearchableOptions: {
      type: Object,
      default: {
        searchApiEndpoint: 'config/floating_devices',
        defaultSortKeys: ['id'], // id is the MAC address
        defaultSearchCondition: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: null },
              { field: 'ip', op: 'contains', value: null }
            ]
          }]
        },
        defaultRoute: { name: 'configuration/floating_devices' }
      }
    },
    tableValues: {
      type: Array,
      default: []
    }
  },
  data () {
    return {
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'id',
          text: 'MAC',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'ip',
          text: 'IP Address',
          types: [conditionType.SUBSTRING]
        }
      ],
      columns: [
        {
          key: 'id',
          label: this.$i18n.t('MAC'),
          sortable: true,
          visible: true
        },
        {
          key: 'ip',
          label: this.$i18n.t('IP Address'),
          sortable: true,
          visible: true
        },
        {
          key: 'pvid',
          label: this.$i18n.t('Native VLAN'),
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
              { field: 'ip', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    },
    onRowClick (item, index) {
      this.$router.push({ name: 'floating_device', params: { id: item.id } })
    }
  },
  created () {
  }
}
</script>
