<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right"><toggle-button v-model="advancedMode">{{ $t('Advanced') }}</toggle-button></div>
      <h4 class="mb-0" v-t="'Search Users'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by name or email"
      :fields="fields" :store="$store" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" :disabled="isLoading" no-caret>
            <template slot="button-content">
              <icon name="columns" v-b-tooltip.hover.right :title="$t('Visible Columns')"></icon>
            </template>
            <b-dropdown-item v-for="column in columns" :key="column.key" @click="toggleColumn(column)">
              <icon class="position-absolute mt-1" name="check" v-show="column.visible"></icon>
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
        @sort-changed="onSortingChanged" @row-clicked="onRowClick" no-local-sorting></b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as attributeType } from '@/globals/pfSearch'
import pfBaseSearchable from '@/components/pfBaseSearchable'
import pfSearch from '@/components/pfSearch'
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'UsersSearch',
  extends: pfBaseSearchable,
  searchApiEndpoint: 'users',
  defaultSortKeys: ['pid'],
  components: {
    'pf-search': pfSearch,
    'toggle-button': ToggleButton
  },
  data () {
    return {
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'pid',
          text: 'Username',
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'email',
          text: 'Email',
          types: [attributeType.SUBSTRING]
        }
      ],
      columns: [
        {
          key: 'pid',
          label: this.$i18n.t('Username'),
          sortable: true,
          visible: true
        },
        {
          key: 'firstname',
          label: this.$i18n.t('Firstname'),
          sortable: true,
          visible: true
        },
        {
          key: 'lastname',
          label: this.$i18n.t('Lastname'),
          sortable: true,
          visible: true
        },
        {
          key: 'email',
          label: this.$i18n.t('Email'),
          sortable: true,
          visible: true
        }
      ]
    }
  },
  methods: {
    quickCondition (newCondition) {
      return {
        op: 'or',
        values: [
          { field: 'pid', op: 'contains', value: newCondition },
          { field: 'email', op: 'contains', value: newCondition }
        ]
      }
    },
    onRowClick (item, index) {
      this.$router.push({ name: 'user', params: { pid: item.pid } })
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
        this.condition.values[0].field === 'pid' &&
        this.condition.values[0].op === 'contains' &&
        this.condition.values[1].field === 'email' &&
        this.condition.values[1].op === 'contains')
    }
  }
}
</script>
