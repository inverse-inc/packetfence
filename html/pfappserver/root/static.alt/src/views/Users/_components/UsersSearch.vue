<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search Users'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" :quick-placeholder="$t('Search by name or email')"
      :fields="fields" :storeName="storeName" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset" @import-search="onImport"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" :disabled="isLoading" no-caret>
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
              <b-pagination align="right" :per-page="pageSizeLimit" :total-rows="totalRows" v-model="requestPage" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table class="table-clickable" :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc" v-model="tableValues"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick" @head-clicked="clearSelected"
        show-empty responsive hover no-local-sorting>
        <template slot="HEAD_actions" slot-scope="head">
          <input type="checkbox" id="checkallnone" v-model="selectAll" @change="onSelectAllChange" @click.stop>
          <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{$t('Select None [ALT+N]')}}</b-tooltip>
          <b-tooltip target="checkallnone" placement="right" v-else>{{$t('Select All [ALT+A]')}}</b-tooltip>
        </template>
        <template slot="actions" slot-scope="data">
          <input type="checkbox" :id="data.value" :value="data.item" v-model="selectValues" @click.stop="onToggleSelected($event, data.index)">
          <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[data.index]._rowMessage" v-b-tooltip.hover.right :title="tableValues[data.index]._rowMessage"></icon>
        </template>
        <template slot="empty">
          <pf-empty-table :isLoading="isLoading">{{ $t('No user found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as attributeType } from '@/globals/pfSearch'
import pfProgress from '@/components/pfProgress'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfMixinSelectable from '@/components/pfMixinSelectable'
import pfFormToggle from '@/components/pfFormToggle'

export default {
  name: 'UsersSearch',
  mixins: [
    pfMixinSelectable,
    pfMixinSearchable
  ],
  components: {
    'pf-progress': pfProgress,
    'pf-empty-table': pfEmptyTable,
    'pf-form-toggle': pfFormToggle
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    pfMixinSearchableOptions: {
      type: Object,
      default: () => ({
        searchApiEndpoint: 'users',
        defaultSortKeys: ['pid'],
        defaultSearchCondition: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'pid', op: 'contains', value: null },
              { field: 'email', op: 'contains', value: null }
            ]
          }]
        },
        defaultRoute: { name: 'users' }
      })
    }
  },
  data () {
    return {
      tableValues: Array,
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'pid',
          text: this.$i18n.t('PID'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'title',
          text: this.$i18n.t('Title'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'firstname',
          text: this.$i18n.t('Firstname'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'lastname',
          text: this.$i18n.t('Lastname'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'nickname',
          text: this.$i18n.t('Nickname'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'email',
          text: this.$i18n.t('Email'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'sponsor',
          text: this.$i18n.t('Sponsor'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'anniversary',
          text: this.$i18n.t('Anniversary'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'birthday',
          text: this.$i18n.t('Birthday'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'address',
          text: this.$i18n.t('Address'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'apartment_number',
          text: this.$i18n.t('Apartment Number'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'building_number',
          text: this.$i18n.t('Building Number'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'room_number',
          text: this.$i18n.t('Room Number'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'company',
          text: this.$i18n.t('Company'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'gender',
          text: this.$i18n.t('Gender'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'lang',
          text: this.$i18n.t('Language'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'portal',
          text: this.$i18n.t('Portal'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'psk',
          text: this.$i18n.t('PSK'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'source',
          text: this.$i18n.t('Source'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'cell_phone',
          text: this.$i18n.t('Cellular Phone Number'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'telephone',
          text: this.$i18n.t('Home Telephone Number'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'work_phone',
          text: this.$i18n.t('Work Telephone Number'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'custom_field_1',
          text: this.$i18n.t('Custom Field #1'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'custom_field_2',
          text: this.$i18n.t('Custom Field #2'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'custom_field_3',
          text: this.$i18n.t('Custom Field #3'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'custom_field_4',
          text: this.$i18n.t('Custom Field #4'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'custom_field_5',
          text: this.$i18n.t('Custom Field #5'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'custom_field_6',
          text: this.$i18n.t('Custom Field #6'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'custom_field_7',
          text: this.$i18n.t('Custom Field #7'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'custom_field_8',
          text: this.$i18n.t('Custom Field #8'),
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'custom_field_9',
          text: this.$i18n.t('Custom Field #9'),
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
          key: 'title',
          label: this.$i18n.t('Title'),
          sortable: true,
          visible: false
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
          key: 'nickname',
          label: this.$i18n.t('Nickname'),
          sortable: true,
          visible: false
        },
        {
          key: 'email',
          label: this.$i18n.t('Email'),
          sortable: true,
          visible: true
        },
        {
          key: 'sponsor',
          label: this.$i18n.t('Sponsor'),
          sortable: true,
          visible: false
        },
        {
          key: 'anniversary',
          label: this.$i18n.t('Anniversary'),
          sortable: true,
          visible: false
        },
        {
          key: 'birthday',
          label: this.$i18n.t('Birthday'),
          sortable: true,
          visible: false
        },
        {
          key: 'address',
          label: this.$i18n.t('Address'),
          sortable: true,
          visible: false
        },
        {
          key: 'apartment_number',
          label: this.$i18n.t('Apartment Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'building_number',
          label: this.$i18n.t('Building Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'room_number',
          label: this.$i18n.t('Room Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'company',
          label: this.$i18n.t('Company'),
          sortable: true,
          visible: false
        },
        {
          key: 'gender',
          label: this.$i18n.t('Gender'),
          sortable: true,
          visible: false
        },
        {
          key: 'lang',
          label: this.$i18n.t('Language'),
          sortable: true,
          visible: false
        },
        {
          key: 'notes',
          label: this.$i18n.t('Notes'),
          sortable: true,
          visible: false
        },
        {
          key: 'portal',
          label: this.$i18n.t('Portal'),
          sortable: true,
          visible: false
        },
        {
          key: 'psk',
          label: this.$i18n.t('PSK'),
          sortable: true,
          visible: false
        },
        {
          key: 'source',
          label: this.$i18n.t('Source'),
          sortable: true,
          visible: false
        },
        {
          key: 'cell_phone',
          label: this.$i18n.t('Cellular Phone Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'telephone',
          label: this.$i18n.t('Home Telephone Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'work_phone',
          label: this.$i18n.t('Work Telephone Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_1',
          label: this.$i18n.t('Custom Field #1'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_2',
          label: this.$i18n.t('Custom Field #2'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_3',
          label: this.$i18n.t('Custom Field #3'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_4',
          label: this.$i18n.t('Custom Field #4'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_5',
          label: this.$i18n.t('Custom Field #5'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_6',
          label: this.$i18n.t('Custom Field #6'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_7',
          label: this.$i18n.t('Custom Field #7'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_8',
          label: this.$i18n.t('Custom Field #8'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_9',
          label: this.$i18n.t('Custom Field #9'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
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
      return condition.values.length > 1 ||
        condition.values[0].values.filter(v => {
          return this.pfMixinSearchableOptions.defaultSearchCondition.values[0].values.findIndex(d => {
            return d.field === v.field && d.op === v.op
          }) >= 0
        }).length !== condition.values[0].values.length
    },
    onRowClick (item, index) {
      this.$router.push({ name: 'user', params: { pid: item.pid } })
    }
  }
}
</script>
