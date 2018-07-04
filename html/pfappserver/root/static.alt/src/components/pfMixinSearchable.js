/**
 * Mixin for search components.
 *
 * A component using the pfMixinSearchable mixin component is required to:
 *
 *   1. declare a property 'pfMixinSearchableOptions' with the following structure:
 *     - declare a property 'searchApiEndpoint' (string);
 *     - declare a property 'defaultSearchKeys' (array);
 *     - declare a property 'defaultSearchCondition' (object);
 *     - declare a property 'defaultRoute' (object);
 *
 *      export default {
 *        // ...
 *        pfMixinSearchableOptions: {
 *          searchApiEndpoint: 'users',
 *          defaultSortKeys: ['pid'],
 *          defaultSearchCondition: { op: 'and', values: [{ op: 'or', values: [{ field: 'pid', op: null, value: null }] }] },
 *          defaultRoute: { name: 'user' }
 *        }
 *        // ...
 *      }
 *
 *   2. declare a data attribute named 'fields';
 *   3. declare a data attribute named 'columns'.
 *
 * Optionally, it can:
 *
 *   - implement a method name 'pfMixinSearchableInitCondition' (used when the search is reset or cleared).
 *   - implement a method name 'pfMixinSearchableQuickCondition' (used when predefining search fields in quick mode).
 *   - implement a method name 'pfMixinSearchableAdvancedMode' (used when determining if advanced mode is enabled).
 *
 */
import pfSearch from '@/components/pfSearch'
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'pfMixinSearchable',
  pfMixinSearchableOptions: {
    defaultSearchCondition: { op: 'and', values: [{ op: 'or', values: [{ field: null, op: null, value: null }] }] }
  },
  components: {
    'pf-search': pfSearch,
    'toggle-button': ToggleButton
  },
  props: {
    query: {
      type: String,
      default: null
    }
  },
  data () {
    return {
      advancedMode: false,
      condition: null,
      query: null,
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 10
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.$options.storeName}_searchable/isLoadingResults`]
    },
    sortBy () {
      return this.$store.state[this.$options.storeName + '_searchable'].searchSortBy
    },
    sortDesc () {
      return this.$store.state[this.$options.storeName + '_searchable'].searchSortDesc
    },
    visibleColumns () {
      return this.columns.filter(column => column.visible)
    },
    searchFields () {
      return this.visibleColumns.filter(column => !column.locked).map(column => column.key)
    },
    items () {
      return this.$store.state[this.$options.storeName + '_searchable'].results
    },
    totalRows () {
      return this.$store.state[this.$options.storeName + '_searchable'].searchMaxPageNumber * this.pageSizeLimit
    }
  },
  methods: {
    onSearch (searchCondition) {
      const _this = this
      let condition = searchCondition
      if (!this.advancedMode && typeof searchCondition === 'string' && typeof this.pfMixinSearchableQuickCondition === 'function') {
        // Build quick search query
        condition = this.pfMixinSearchableQuickCondition(searchCondition)
      }
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this.$options.storeName}_searchable/setSearchQuery`, condition)
      this.$store.dispatch(`${this.$options.storeName}_searchable/search`, this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
        _this.condition = condition
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
      // pfMixinSelectable
      if (this.$options.methods.clearSelected) {
        this.clearSelected()
      }
    },
    onReset () {
      const _this = this
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this.$options.storeName}_searchable/setSearchQuery`, null) // reset search
      this.$store.dispatch(`${this.$options.storeName}_searchable/search`, this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
        this.pfMixinSearchableInitCondition()
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
      this.$router.push(this.$options.pfMixinSearchableOptions.defaultRoute)
    },
    onImport (condition) {
      this.$router.push(Object.assign(this.$options.pfMixinSearchableOptions.defaultRoute, { query: { query: JSON.stringify(condition) } }))
    },
    pfMixinSearchableInitCondition () {
      this.condition = JSON.parse(JSON.stringify(this.$options.pfMixinSearchableOptions.defaultSearchCondition))
    },
    onPageSizeChange () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this.$options.storeName}_searchable/setSearchPageSize`, this.pageSizeLimit)
      this.$store.dispatch(`${this.$options.storeName}_searchable/search`, this.requestPage)
    },
    onPageChange () {
      const _this = this
      this.$store.dispatch(`${this.$options.storeName}_searchable/search`, this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onSortingChanged (params) {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this.$options.storeName}_searchable/setSearchSorting`, params)
      this.$store.dispatch(`${this.$options.storeName}_searchable/search`, this.requestPage)
    },
    toggleColumn (column) {
      column.visible = !column.visible
      this.$store.dispatch(`${this.$options.storeName}_searchable/setVisibleColumns`, this.columns.filter(column => column.visible).map(column => column.key))
      this.$store.dispatch(`${this.$options.storeName}_searchable/setSearchFields`, this.searchFields)
      if (column.visible) {
        this.$store.dispatch(`${this.$options.storeName}_searchable/search`, this.requestPage)
      }
    }
  },
  watch: {
    query (a, b) {
      if (a !== b) {
        if (a) {
          const condition = JSON.parse(a)
          this.onSearch(condition)
        }
      }
    },
    condition: {
      handler: function (a, b) {
        if (a !== b) {
          if (a === undefined || a === null) {
            // empty query, re-initialize
            this.pfMixinSearchableInitCondition()
          } else if (typeof this.pfMixinSearchableAdvancedMode === 'function') {
            // enable advancedMode (if not already)
            this.advancedMode = (this.pfMixinSearchableAdvancedMode(a)) ? true : this.advancedMode
          }
        }
      },
      immediate: true,
      deep: true
    }
  },
  created () {
    // Called before the component's created function.
    if (!this.$options.pfMixinSearchableOptions) {
      throw new Error(`Missing 'pfMixinSearchableOptions' in properties of component ${this.$options.name}`)
    }
    if (!this.$options.pfMixinSearchableOptions.searchApiEndpoint) {
      throw new Error(`Missing 'pfMixinSearchableOptions.searchApiEndpoint' in properties of component ${this.$options.name}`)
    }
    if (!this.$options.pfMixinSearchableOptions.defaultSortKeys) {
      throw new Error(`Missing 'pfMixinSearchableOptions.defaultSortKeys' in properties of component ${this.$options.name}`)
    }
    if (!this.$options.pfMixinSearchableOptions.defaultSearchCondition) {
      throw new Error(`Missing 'pfMixinSearchableOptions.defaultSearchCondition' in properties of component ${this.$options.name}`)
    }
    if (!this.$options.pfMixinSearchableOptions.defaultRoute) {
      throw new Error(`Missing 'pfMixinSearchableOptions.defaultRoute' in properties of component ${this.$options.name}`)
    }
    if (!this.fields) {
      throw new Error(`Missing 'fields' in data of component ${this.$options.name}`)
    }
    if (!this.columns) {
      throw new Error(`Missing 'columns' in data of component ${this.$options.name}`)
    }
    this.pageSizeLimit = this.$store.state[this.$options.storeName + '_searchable'].searchPageSize
    // The extended component is responsible to set the condition to a specific state when unset
    this.condition = this.$store.state[this.$options.storeName + '_searchable'].searchQuery
    // Restore visibleColumns, overwrite defaults
    if (this.$store.state[this.$options.storeName + '_searchable'].visibleColumns) {
      const visibleColumns = this.$store.state[this.$options.storeName + '_searchable'].visibleColumns
      this.columns.forEach(function (column, index, columns) {
        columns[index].visible = visibleColumns.includes(column.key)
      })
    }
    this.$store.dispatch(`${this.$options.storeName}_searchable/setSearchFields`, this.searchFields)
    // fake loop to allow multiple breaks w/ fallback to default
    do {
      try {
        if (this.query) {
          // Import search parameters from URL query
          this.condition = JSON.parse(this.query)
          break
        } else if (this.$store.state[this.$options.storeName + '_searchable'].searchQuery) {
          // Restore search parameters from store
          this.condition = this.$store.state[this.$options.storeName + '_searchable'].searchQuery
          break
        }
      } catch (e) {
        // noop
      }
      // Import default condition
      this.pfMixinSearchableInitCondition()
    } while (false)
  },
  mounted () {
    if (JSON.stringify(this.condition) === JSON.stringify(this.$options.pfMixinSearchableOptions.defaultSearchCondition)) {
      // query all w/o criteria
      this.$store.dispatch(`${this.$options.storeName}_searchable/setSearchQuery`, null)
    } else {
      this.$store.dispatch(`${this.$options.storeName}_searchable/setSearchQuery`, this.condition)
    }
    this.$store.dispatch(`${this.$options.storeName}_searchable/search`, this.requestPage)
  }
}
