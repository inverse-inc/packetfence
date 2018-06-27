/**
 * Base component for search components.
 *
 * A component extending the pfBaseSearch component is required to:
 *
 *   - declare a property 'pfBaseSearchableOptions' with the following structure:
 *     - declare a property 'searchApiEndpoint' (string);
 *     - declare a property 'defaultSearchKeys' (array);
 *     - declare a property 'defaultSearchCondition' (object);
 *     - declare a property 'defaultRoute' (object);
 *
 *     pfBaseSearchableOptions: {
 *       searchApiEndpoint: 'users',
 *       defaultSortKeys: ['pid'],
 *       defaultSearchCondition: { op: 'and', values: [{ op: 'or', values: [{ field: 'pid', op: null, value: null }] }] },
  *      defaultRoute: { name: 'user' }
 *     }
 *
 *   - declare a data attribute named 'fields';
 *   - declare a data attribute named 'columns'.
 *
 * Optionally, it can:
 *
 *   - implement a method name 'pfBaseSearchableInitCondition' (used when the search is reset or cleared).
 *   - implement a method name 'pfBaseSearchableQuickCondition' (used when predefining search fields in quick mode).
 */
import SearchableStore from '@/store/base/searchable'
import pfSearch from '@/components/pfSearch'
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'pfBaseSearchable',
  pfBaseSearchableOptions: {
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
      return this.visibleColumns.filter(column => !column.locked).map(column => column.key)
    },
    items () {
      return this.$store.state[this._storeName].results
    },
    totalRows () {
      return this.$store.state[this._storeName].searchMaxPageNumber * this.pageSizeLimit
    }
  },
  methods: {
    onSearch (searchCondition) {
      const _this = this
      let condition = searchCondition
      if (!this.advancedMode && typeof this.pfBaseSearchableQuickCondition === 'function') {
        // Build quick search query
        condition = this.pfBaseSearchableQuickCondition(searchCondition)
      }
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this._storeName}/setSearchQuery`, condition)
      this.$store.dispatch(`${this._storeName}/search`, this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
        _this.condition = condition
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
      // pfBaseSelectable
      if (this.$options.methods.clearSelected) {
        this.clearSelected()
      }
    },
    onReset () {
      const _this = this
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this._storeName}/setSearchQuery`, null) // reset search
      this.$store.dispatch(`${this._storeName}/search`, this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
        this.pfBaseSearchableInitCondition()
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
      this.$router.push(this.$options.pfBaseSearchableOptions.defaultRoute)
    },
    onImport (condition) {
      this.$router.push(Object.assign(this.$options.pfBaseSearchableOptions.defaultRoute, { query: { query: JSON.stringify(condition) } }))
    },
    pfBaseSearchableInitCondition () {
      this.condition = JSON.parse(JSON.stringify(this.$options.pfBaseSearchableOptions.defaultSearchCondition))
    },
    onPageSizeChange () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this._storeName}/setSearchPageSize`, this.pageSizeLimit)
      this.$store.dispatch(`${this._storeName}/search`, this.requestPage)
    },
    onPageChange () {
      const _this = this
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
            this.pfBaseSearchableInitCondition()
          } else if (a.values.length > 1 || a.values[0].values.length > 1) {
            this.advancedMode = true
          }
        }
      },
      immediate: true,
      deep: true
    }
  },
  created () {
    // Called before the component's created function.
    if (!this.$options.pfBaseSearchableOptions) {
      throw new Error(`Missing 'pfBaseSearchableOptions' in properties of component ${this.$options.name}`)
    }
    if (!this.$options.pfBaseSearchableOptions.searchApiEndpoint) {
      throw new Error(`Missing 'pfBaseSearchableOptions.searchApiEndpoint' in properties of component ${this.$options.name}`)
    }
    if (!this.$options.pfBaseSearchableOptions.defaultSortKeys) {
      throw new Error(`Missing 'pfBaseSearchableOptions.defaultSortKeys' in properties of component ${this.$options.name}`)
    }
    if (!this.$options.pfBaseSearchableOptions.defaultSearchCondition) {
      throw new Error(`Missing 'pfBaseSearchableOptions.defaultSearchCondition' in properties of component ${this.$options.name}`)
    }
    if (!this.$options.pfBaseSearchableOptions.defaultRoute) {
      throw new Error(`Missing 'pfBaseSearchableOptions.defaultRoute' in properties of component ${this.$options.name}`)
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
      const searchableStore = new SearchableStore(this.$options.pfBaseSearchableOptions.searchApiEndpoint, this.$options.pfBaseSearchableOptions.defaultSortKeys)
      this.$store.registerModule(this._storeName, searchableStore.module())
      console.debug(`Registered store module ${this._storeName}`)
    }
    this.pageSizeLimit = this.$store.state[this._storeName].searchPageSize
    // The extended component is responsible to set the condition to a specific state when unset
    this.condition = this.$store.state[this._storeName].searchQuery
    // Restore visibleColumns, overwrite defaults
    if (this.$store.state[this._storeName].visibleColumns) {
      const visibleColumns = this.$store.state[this._storeName].visibleColumns
      this.columns.forEach(function (column, index, columns) {
        columns[index].visible = visibleColumns.includes(column.key)
      })
    }
    this.$store.dispatch(`${this._storeName}/setSearchFields`, this.searchFields)
    // fake loop to allow multiple breaks w/ fallback to default
    do {
      try {
        if (this.query) {
          // Import search parameters from URL query
          this.condition = JSON.parse(this.query)
          break
        } else if (this.$store.state[this._storeName].searchQuery) {
          // Restore search parameters from store
          this.condition = this.$store.state[this._storeName].searchQuery
          break
        }
      } catch (e) {
        // noop
      }
      // Import default condition
      this.pfBaseSearchableInitCondition()
    } while (false)
  },
  mounted () {
    if (JSON.stringify(this.condition) === JSON.stringify(this.$options.pfBaseSearchableOptions.defaultSearchCondition)) {
      // query all w/o criteria
      this.$store.dispatch(`${this._storeName}/setSearchQuery`, null)
    } else {
      this.$store.dispatch(`${this._storeName}/setSearchQuery`, this.condition)
    }
    this.$store.dispatch(`${this._storeName}/search`, this.requestPage)
  }
}
