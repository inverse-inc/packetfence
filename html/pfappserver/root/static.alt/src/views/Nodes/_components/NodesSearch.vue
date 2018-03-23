<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right"><toggle-button v-model="advancedMode">{{ $t('Advanced') }}</toggle-button></div>
      <h4 class="mb-0" v-t="'Search Nodes'"></h4>
    </b-card-header>
    <pf-search :fields="fields" :store="$store" :advanced-mode="advancedMode" :condition="condition"
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
      <b-table stacked="sm" :items="items" :fields="columns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick" hover no-local-sorting></b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import pfSearch from '@/components/pfSearch'
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'NodesSearch',
  components: {
    'pf-search': pfSearch,
    'toggle-button': ToggleButton
  },
  props: {
    namedSearch: String
  },
  data () {
    return {
      advancedMode: false,
      /**
       *  Fields on which a search can be defined.
       *  The names must match the database schema.
       *  The keys must conform to the format of the b-form-select's options property.
       */
      fields: [ // keys match with b-form-select
        {
          value: 'mac',
          text: 'MAC Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'computername',
          text: 'Computer Name',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'bypass_role_id',
          text: 'Bypass Role',
          types: [conditionType.ROLE, conditionType.SUBSTRING]
        },
        {
          value: 'locationlog.connection_type',
          text: 'Connection Type',
          types: [conditionType.CONNECTION_TYPE]
        },
        {
          value: 'category_id',
          text: 'Node Role',
          types: [conditionType.ROLE, conditionType.SUBSTRING]
        },
        {
          value: 'voip',
          text: 'VoIP',
          types: [conditionType.BOOL]
        }
      ],
      /**
       * The columns that can be displayed in the results table.
       */
      columns: [
        {
          key: 'mac',
          label: this.$i18n.t('MAC Address'),
          sortable: true
        },
        {
          key: 'computername',
          label: this.$i18n.t('Computer Name'),
          sortable: true
        },
        {
          key: 'pid',
          label: this.$i18n.t('Owner'),
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
      return this.$store.getters['$_nodes/isLoading']
    },
    sortBy () {
      return this.$store.state.$_nodes.searchSortBy
    },
    sortDesc () {
      return this.$store.state.$_nodes.searchSortDesc
    },
    items () {
      return this.$store.state.$_nodes.items
    },
    totalRows () {
      return this.$store.state.$_nodes.searchMaxPageNumber * this.pageSizeLimit
    }
  },
  methods: {
    onSearch (condition) {
      let _this = this
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_nodes/setSearchQuery', condition)
      this.$store.dispatch('$_nodes/search', this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
        _this.condition = condition
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onReset () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_nodes/setSearchQuery', undefined) // reset search
      this.$store.dispatch('$_nodes/search', this.requestPage)
    },
    onPageSizeChange () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_nodes/setSearchPageSize', this.pageSizeLimit)
      this.$store.dispatch('$_nodes/search', this.requestPage)
    },
    onPageChange () {
      let _this = this
      this.$store.dispatch('$_nodes/search', this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onSortingChanged (params) {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_nodes/setSearchSorting', params)
      this.$store.dispatch('$_nodes/search', this.requestPage)
    },
    onRowClick (item, index) {
      this.$router.push({ name: 'node', params: { mac: item.mac } })
    }
  },
  created () {
    this.$store.dispatch('$_nodes/search', this.requestPage)
    if (this.$store.state.config.roles.length === 0) {
      this.$store.dispatch('config/getRoles')
      this.pageSizeLimit = this.$store.state.$_nodes.searchPageSize
      // Restore search parameters
      this.condition = this.$store.state.$_nodes.searchQuery
    }
  }
}
</script>

