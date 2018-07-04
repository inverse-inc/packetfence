<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right"><toggle-button v-model="advancedMode" :sync="true">{{ $t('Advanced') }}</toggle-button></div>
      <h4 class="mb-0" v-t="'Search Users'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" :quick-placeholder="$t('Search by name or email')"
      :fields="fields" :store="$store" storeName="$_users" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset" @import-search="onImport"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" :disabled="isLoading" no-caret>
            <template slot="button-content">
              <icon name="columns" v-b-tooltip.hover.right :title="$t('Visible Columns')"></icon>
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
              <b-pagination align="right" :per-page="pageSizeLimit" :total-rows="totalRows" v-model="requestPage" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table hover :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick" @head-clicked="clearSelected" no-local-sorting v-model="tableValues">
        <template slot="HEAD_actions" slot-scope="head">
          <input type="checkbox" id="checkallnone" v-model="selectAll" @change="onSelectAllChange" @click.stop>
          <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{$t('Select None [ALT+N]')}}</b-tooltip>
          <b-tooltip target="checkallnone" placement="right" v-else>{{$t('Select All [ALT+A]')}}</b-tooltip>
        </template>
        <template slot="actions" slot-scope="data">
          <input type="checkbox" :id="data.value" :value="data.item" v-model="selectValues" @click.stop="onToggleSelected($event, data.index)">
          <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[data.index]._message" v-b-tooltip.hover.right :title="tableValues[data.index]._message"></icon>
        </template>

      </b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as attributeType } from '@/globals/pfSearch'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfMixinSelectable from '@/components/pfMixinSelectable'

export default {
  name: 'UsersSearch',
  storeName: '$_users',
  mixins: [
    pfMixinSelectable,
    pfMixinSearchable
  ],
  pfMixinSearchableOptions: {
    searchApiEndpoint: 'users',
    defaultSortKeys: ['pid'],
    defaultSearchCondition: { op: 'and', values: [{ op: 'or', values: [{ field: 'pid', op: 'equals', value: null }] }] },
    defaultRoute: { name: 'users' }
  },
  components: {
  },
  props: {
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
          key: 'actions',
          label: this.$i18n.t('Actions'),
          sortable: false,
          visible: true,
          locked: true,
          formatter: (value, key, item) => {
            return item.mac
          }
        },
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
    pfMixinSearchableQuickCondition (quickCondition) {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'pid', op: 'contains', value: quickCondition },
              { field: 'email', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    },
    pfMixinSearchableAdvancedMode (condition) {
      return condition.values.length > 1 || !(
        condition.values[0].values.length === 2 &&
        condition.values[0].values[0].field === 'pid' &&
        condition.values[0].values[0].op === 'contains' &&
        condition.values[0].values[1].field === 'email' &&
        condition.values[0].values[1].op === 'contains' &&
        condition.values[0].values[0].value === condition.values[0].values[1].value
      )
    },
    onRowClick (item, index) {
      this.$router.push({ name: 'user', params: { pid: item.pid } })
    }
  },
  watch: {
    selectValues (a, b) {
      const _this = this
      const selectValues = this.selectValues
      this.tableValues.forEach(function (item, index, items) {
        if (selectValues.includes(item)) {
          _this.$store.commit(`${_this._storeName}/ROW_VARIANT`, {index: index, variant: 'info'})
        } else {
          _this.$store.commit(`${_this._storeName}/ROW_VARIANT`, {index: index, variant: ''})
          _this.$store.commit(`${_this._storeName}/ROW_MESSAGE`, {index: index, message: ''})
        }
      })
    }
  },
  created () {
    this._storeName = '$_' + this.$options.name.toLowerCase()
  }
}
</script>
