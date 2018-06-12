<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right"><toggle-button v-model="advancedMode">{{ $t('Advanced') }}</toggle-button></div>
      <h4 class="mb-0" v-t="'Search RADIUS Audit Logs'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by MAC or username"
      :fields="fields" :store="$store" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" :disabled="isLoading" no-caret>
            <template slot="button-content">
              <icon name="columns" v-b-tooltip.hover.right :title="$t('Visible Columns')"></icon>
            </template>
            <b-dropdown-item v-for="column in columns" :key="column.key" @click="toggleColumn(column)"
              v-if="!column.locked || column.visible" :disabled="column.locked">
              <icon class="position-absolute mt-1" name="thumbtack" v-if="column.locked"></icon>
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
              <b-pagination align="right" :per-page="pageSizeLimit" :total-rows="totalRows" v-model="requestPage" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table hover :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick" no-local-sorting>
        <template slot="mac" slot-scope="log">
          <mac v-text="log.item.mac"></mac>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as attributeType } from '@/globals/pfSearch'
import pfBaseSearchable from '@/components/pfBaseSearchable'
import pfSearch from '@/components/pfSearch'
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'RadiusLogsSearch',
  extends: pfBaseSearchable,
  searchApiEndpoint: 'radius_audit_logs',
  defaultSortKeys: ['created_at', 'mac'],
  components: {
    'pf-search': pfSearch,
    'toggle-button': ToggleButton
  },
  data () {
    return {
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'user_name',
          text: 'Username',
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'mac',
          text: 'MAC Address',
          types: [attributeType.SUBSTRING]
        }
      ],
      columns: [
        {
          key: 'id',
          label: this.$i18n.t('ID'),
          sortable: true,
          visible: false,
          locked: true
        },
        {
          key: 'auth_status',
          label: this.$i18n.t('Auth Status'),
          sortable: true,
          visible: true
        },
        {
          key: 'mac',
          label: this.$i18n.t('MAC Address'),
          sortable: true,
          visible: true
        },
        {
          key: 'node_status',
          label: this.$i18n.t('Node Status'),
          sortable: true,
          visible: true
        },
        {
          key: 'user_name',
          label: this.$i18n.t('Username'),
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
          key: 'created_at',
          label: this.$i18n.t('Created At'),
          sortable: true,
          visible: true
        }
      ]
    }
  },
  methods: {
    quickCondition (newCondition) {
      // Build full condition from quick value;
      // Called from pfBaseSearchable.onSearch().
      return {
        op: 'or',
        values: [
          { field: 'mac', op: 'contains', value: newCondition },
          { field: 'user_name', op: 'contains', value: newCondition }
        ]
      }
    },
    onRowClick (item, index) {
      this.$router.push({ name: 'view', params: { id: item.id } })
    }
  },
  created () {
    // pfBaseSearchable.created() has been called
    if (!this.condition) {
      // Select first field
      this.initCondition()
    } else {
      // Restore selection of advanced mode; check if condition matches a quick search
      this.advancedMode = !(this.condition.op === 'or' &&
        this.condition.values.length === 2 &&
        this.condition.values[0].field === 'mac' &&
        this.condition.values[0].op === 'contains' &&
        this.condition.values[1].field === 'user_name' &&
        this.condition.values[1].op === 'contains')
    }
  }
}
</script>
