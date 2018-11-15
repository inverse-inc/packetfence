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
 *        props: {
 *          pfMixinSearchableOptions: {
 *            type: Object,
 *            default: {
 *              searchApiEndpoint: 'users',
 *              defaultSortKeys: ['pid'],
 *              defaultSearchCondition: { op: 'and', values: [{ op: 'or', values: [{ field: 'pid', op: null, value: null }] }] },
 *              defaultRoute: { name: 'user' }
 *            }
 *          },
 *          // ...
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
import SearchableStore from '@/store/base/searchable'
import pfSearch from '@/components/pfSearch'

export default {
  name: 'pfMixinSearchable',
  components: {
    'pf-search': pfSearch
  },
  props: {
    pfMixinSearchableOptions: {
      type: Object,
      default: {
        defaultSearchCondition: { op: 'and', values: [{ op: 'or', values: [{ field: null, op: null, value: null }] }] }
      }
    },
    query: {
      type: String,
      default: null
    }
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
      if (this.searchableStoreName) {
        return this.$store.getters[`${this.searchableStoreName}/isLoadingResults`]
      }
    },
    sortBy () {
      if (this.searchableStoreName) {
        return this.$store.state[this.searchableStoreName].searchSortBy
      }
    },
    sortDesc () {
      if (this.searchableStoreName) {
        return this.$store.state[this.searchableStoreName].searchSortDesc
      }
    },
    visibleColumns () {
      return this.columns.filter(column => column.visible)
    },
    searchFields () {
      return this.visibleColumns.filter(column => !column.locked).map(column => column.key)
    },
    items () {
      if (this.searchableStoreName) {
        let results = this.$store.state[this.searchableStoreName].results
        if ('resultsFilter' in this.pfMixinSearchableOptions) {
          results = this.pfMixinSearchableOptions.resultsFilter(results)
        }
        return results
      }
    },
    totalRows () {
      if (this.searchableStoreName) {
        return this.$store.state[this.searchableStoreName].searchMaxPageNumber * this.pageSizeLimit
      }
    },
    searchableStoreName () {
      if (this.pfMixinSearchableOptions.searchApiEndpoint) {
        return '$_' + this.pfMixinSearchableOptions.searchApiEndpoint.replace(/[/]/g, '_').replace(/[-: ]/g, '') + '_searchable'
      } else {
        return undefined
      }
    }
  },
  methods: {
    initStore () {
      if (!this.$store.state[this.searchableStoreName]) {
        // Register store module only once
        const searchableStore = new SearchableStore(
          this.pfMixinSearchableOptions.searchApiEndpoint,
          this.pfMixinSearchableOptions.defaultSortKeys
        )
        this.$store.registerModule(this.searchableStoreName, searchableStore.module())
      }
      this.pageSizeLimit = this.$store.state[this.searchableStoreName].searchPageSize
      // The extended component is responsible to set the condition to a specific state when unset
      this.condition = this.$store.state[this.searchableStoreName].searchQuery
      // Restore visibleColumns, overwrite defaults
      if (this.$store.state[this.searchableStoreName].visibleColumns) {
        const visibleColumns = this.$store.state[this.searchableStoreName].visibleColumns
        this.columns.forEach(function (column, index, columns) {
          columns[index].visible = visibleColumns.includes(column.key)
        })
      }
      this.$store.dispatch(`${this.searchableStoreName}/setSearchFields`, this.searchFields)
      // Fake loop to allow multiple breaks w/ fallback to default
      do {
        try {
          if (this.query) {
            // Import search parameters from URL query
            this.condition = JSON.parse(this.query)
            break
          } else if (this.$store.state[this.searchableStoreName].searchQuery) {
            // Restore search parameters from store
            this.condition = this.$store.state[this.searchableStoreName].searchQuery
            break
          }
        } catch (e) {
          // noop
        }
        // Import default condition
        this.pfMixinSearchableInitCondition()
      } while (false)
    },
    onSearch (searchCondition) {
      const _this = this
      let condition = searchCondition
      if (!this.advancedMode && typeof searchCondition === 'string' && typeof this.pfMixinSearchableQuickCondition === 'function') {
        // Build quick search query
        condition = this.pfMixinSearchableQuickCondition(searchCondition)
      }
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this.searchableStoreName}/setSearchQuery`, condition)
      this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage).then(() => {
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
      this.$store.dispatch(`${this.searchableStoreName}/setSearchQuery`, null) // reset search
      this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
        this.pfMixinSearchableInitCondition()
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
      this.$router.push(this.pfMixinSearchableOptions.defaultRoute)
    },
    onImport (condition) {
      this.$router.push(Object.assign(this.pfMixinSearchableOptions.defaultRoute, { query: { query: JSON.stringify(condition) } }))
    },
    pfMixinSearchableInitCondition () {
      this.condition = JSON.parse(JSON.stringify(this.pfMixinSearchableOptions.defaultSearchCondition))
    },
    onPageSizeChange () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this.searchableStoreName}/setSearchPageSize`, this.pageSizeLimit)
      this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage)
    },
    onPageChange () {
      const _this = this
      this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onSortingChanged (params) {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this.searchableStoreName}/setSearchSorting`, params)
      this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage)
    },
    toggleColumn (column) {
      column.visible = !column.visible
      this.$store.dispatch(`${this.searchableStoreName}/setVisibleColumns`, this.columns.filter(column => column.visible).map(column => column.key))
      this.$store.dispatch(`${this.searchableStoreName}/setSearchFields`, this.searchFields)
      if (column.visible) {
        this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage)
      }
    }
  },
  watch: {
    searchableStoreName (value) {
      this.initStore()
    },
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
        // clear if query param !== condition
        if (a && JSON.stringify(a) !== this.query) {
          this.$router.push({ query: null })
        }
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
    // called before the component's created function.
    if (!this.pfMixinSearchableOptions) {
      throw new Error(`Missing 'pfMixinSearchableOptions' in properties of component ${this.$options.name}`)
    }
    if (!this.pfMixinSearchableOptions.hasOwnProperty('searchApiEndpoint')) {
      throw new Error(`Missing 'pfMixinSearchableOptions.searchApiEndpoint' in properties of component ${this.$options.name}`)
    }
    if (!this.pfMixinSearchableOptions.hasOwnProperty('defaultSortKeys')) {
      throw new Error(`Missing 'pfMixinSearchableOptions.defaultSortKeys' in properties of component ${this.$options.name}`)
    }
    if (!this.pfMixinSearchableOptions.hasOwnProperty('defaultSearchCondition')) {
      throw new Error(`Missing 'pfMixinSearchableOptions.defaultSearchCondition' in properties of component ${this.$options.name}`)
    }
    if (!this.pfMixinSearchableOptions.hasOwnProperty('defaultRoute')) {
      throw new Error(`Missing 'pfMixinSearchableOptions.defaultRoute' in properties of component ${this.$options.name}`)
    }
    if (!this.fields) {
      throw new Error(`Missing 'fields' in data of component ${this.$options.name}`)
    }
    if (!this.columns) {
      throw new Error(`Missing 'columns' in data of component ${this.$options.name}`)
    }
    if (this.pfMixinSearchableOptions.hasOwnProperty('searchApiEndpoint') && this.pfMixinSearchableOptions.searchApiEndpoint) {
      this.initStore()
    }
  },
  mounted () {
    // called after the component's mounted function.
    if (JSON.stringify(this.condition) === JSON.stringify(this.pfMixinSearchableOptions.defaultSearchCondition)) {
      // query all w/o criteria
      this.$store.dispatch(`${this.searchableStoreName}/setSearchQuery`, null)
    } else {
      this.$store.dispatch(`${this.searchableStoreName}/setSearchQuery`, this.condition)
    }
    this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage)
  }
}
