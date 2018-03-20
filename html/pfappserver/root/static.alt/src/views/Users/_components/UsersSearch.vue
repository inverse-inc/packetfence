<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right"><toggle-button v-model="advancedMode">{{ $t('Advanced') }}</toggle-button></div>
      <h4 class="mb-0" v-t="'Search Users'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by name or email"
      :fields="fields" :store="$store" :advanced-mode="advancedMode"
      @submit-search="onSearch" @reset-search="onReset"></pf-search>
    <div class="card-body">
      <b-row align-h="end">
        <b-form inline>
          <b-form-select class="mb-3 mr-3" size="sm" v-model="pageSizeLimit" :options="[10,25,50,100]" :disabled="isLoading"
            @input="onPageSizeChange" />
        </b-form>
        <b-pagination align="right" :per-page="pageSizeLimit" :total-rows="totalRows" v-model="requestPage" :disabled="isLoading"
          @input="onPageChange" />
      </b-row>
      <b-table hover :items="items" :fields="columns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick" no-local-sorting></b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as attributeType } from '@/globals/pfSearch'
import pfSearch from '@/components/pfSearch'
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'UsersSearch',
  components: {
    'pf-search': pfSearch,
    'toggle-button': ToggleButton
  },
  data () {
    return {
      advancedMode: false,
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
          sortable: true
        },
        {
          key: 'firstname',
          label: this.$i18n.t('firstname'),
          sortable: true
        },
        {
          key: 'lastname',
          label: this.$i18n.t('lastname'),
          sortable: true
        },
        {
          key: 'email',
          label: this.$i18n.t('email'),
          sortable: true
        }
      ],
      condition: null,
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 10
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_users/isLoading']
    },
    sortBy () {
      return this.$store.state.$_users.searchSortBy
    },
    sortDesc () {
      return this.$store.state.$_users.searchSortDesc
    },
    items () {
      return this.$store.state.$_users.items
    },
    totalRows () {
      return this.$store.state.$_users.searchMaxPageNumber * this.pageSizeLimit
    }
  },
  methods: {
    onSearch (newCondition) {
      let _this = this
      let condition = newCondition
      if (!this.advancedMode) {
        // Build quick search query
        condition = {
          op: 'or',
          values: [
            { field: 'pid', op: 'contains', value: newCondition },
            { field: 'email', op: 'contains', value: newCondition }
          ]
        }
      }
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_users/setSearchQuery', condition)
      this.$store.dispatch('$_users/search', this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
        _this.condition = condition
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onReset () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_users/setSearchQuery', undefined) // reset search
      this.$store.dispatch('$_users/search', this.requestPage)
    },
    onPageSizeChange () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_users/setSearchPageSize', this.pageSizeLimit)
      this.$store.dispatch('$_users/search', this.requestPage)
    },
    onPageChange () {
      let _this = this
      this.$store.dispatch('$_users/search', this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onSortingChanged (params) {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_users/setSearchSorting', params)
      this.$store.dispatch('$_users/search', this.requestPage)
    },
    onRowClick (item, index) {
      this.$router.push({ name: 'user', params: { pid: item.pid } })
    }
  },
  created () {
    this.$store.dispatch('$_users/search', this.requestPage)
    this.pageSizeLimit = this.$store.state.$_users.searchPageSize
  }
}
</script>
