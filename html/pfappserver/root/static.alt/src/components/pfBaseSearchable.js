/**
 * Base component for search components.
 *
 * A component extending the pfBaseSearch component requires to:
 *
 *   - declare a property 'searchApiEndpoint';
 *   - declare a property 'defaultSearchKeys' (array);
 *   - declare a data attribute named 'fields';
 *   - declare a data attribute named 'columns'.
 *
 * Optionally, it can:
 *
 *   - implement a method name 'initCondition';
 *   - implement a method name 'quickCondition' (used when predefining search fields in quick mode).
 */
import SearchableStore from '@/store/base/searchable'
import pfSearch from '@/components/pfSearch'
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'pfBaseSearchable',
  components: {
    'pf-search': pfSearch,
    'toggle-button': ToggleButton
  },
  data () {
    return {
      advancedMode: false,
      condition: null,
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 10
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this._storeName}/isLoadingResults`]
    },
    sortBy () {
      return this.$store.state[this._storeName].searchSortBy
    },
    sortDesc () {
      return this.$store.state[this._storeName].searchSortDesc
    },
    visibleColumns () {
      return this.columns.filter(column => column.visible)
    },
    searchFields () {
      return this.visibleColumns.filter(column => column.visible).map(column => column.key)
    },
    items () {
      return this.$store.state[this._storeName].results
    },
    totalRows () {
      return this.$store.state[this._storeName].searchMaxPageNumber * this.pageSizeLimit
    }
  },
  methods: {
    onSearch (newCondition) {
      let _this = this
      let condition = newCondition
      if (!this.advancedMode && typeof this.quickCondition === 'function') {
        // Build quick search query
        condition = this.quickCondition(newCondition)
      }
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this._storeName}/setSearchQuery`, condition)
      this.$store.dispatch(`${this._storeName}/search`, this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
        _this.condition = condition
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onReset () {
      this.$store.dispatch(`${this._storeName}/setSearchQuery`, null) // reset search
      this.$store.dispatch(`${this._storeName}/search`, this.requestPage)
      this.requestPage = 1 // reset to the first page
      this.initCondition()
    },
    initCondition () {
      this.condition = { op: 'and', values: [{ op: 'or', values: [{ field: this.fields[0].value, op: null, value: null }] }] }
    },
    onPageSizeChange () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this._storeName}/setSearchPageSize`, this.pageSizeLimit)
      this.$store.dispatch(`${this._storeName}/search`, this.requestPage)
    },
    onPageChange () {
      let _this = this
      this.$store.dispatch(`${this._storeName}/search`, this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onSortingChanged (params) {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this._storeName}/setSearchSorting`, params)
      this.$store.dispatch(`${this._storeName}/search`, this.requestPage)
    },
    toggleColumn (column) {
      column.visible = !column.visible
      this.$store.dispatch(`${this._storeName}/setVisibleColumns`, this.columns.filter(column => column.visible).map(column => column.key))
      this.$store.dispatch(`${this._storeName}/setSearchFields`, this.searchFields)
      if (column.visible) {
        this.$store.dispatch(`${this._storeName}/search`, this.requestPage)
      }
    }
  },
  created () {
    // Called before the component's created function.
    if (!this.$options.searchApiEndpoint) {
      throw new Error(`Missing 'searchApiEndpoint' in properties of component ${this.$options.name}`)
    }
    if (!this.$options.defaultSortKeys) {
      throw new Error(`Missing 'defaultSortKeys' in properties of component ${this.$options.name}`)
    }
    if (!this.fields) {
      throw new Error(`Missing 'fields' in data of component ${this.$options.name}`)
    }
    if (!this.columns) {
      throw new Error(`Missing 'columns' in data of component ${this.$options.name}`)
    }
    // Store name is build from component name
    this._storeName = '$_' + this.$options.name.toLowerCase()
    if (!this.$store.state[this._storeName]) {
      // Register store module only once
      let searchableStore = new SearchableStore(this.$options.searchApiEndpoint, this.$options.defaultSortKeys)
      this.$store.registerModule(this._storeName, searchableStore.module())
      console.debug(`Registered store module ${this._storeName}`)
    }
    this.pageSizeLimit = this.$store.state[this._storeName].searchPageSize
    // The extended component is responsible to set the condition to a specific state when unset
    this.condition = this.$store.state[this._storeName].searchQuery
    // Restore visibleColumns, overwrite defaults
    if (this.$store.state[this._storeName].visibleColumns) {
      let visibleColumns = this.$store.state[this._storeName].visibleColumns
      this.columns.forEach(function (column, index, columns) {
        columns[index].visible = visibleColumns.includes(column.key)
      })
    }
    this.$store.dispatch(`${this._storeName}/setSearchFields`, this.searchFields)
    this.$store.dispatch(`${this._storeName}/search`, this.requestPage)
  }
}
