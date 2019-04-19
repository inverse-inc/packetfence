/**
 * Mixin for search components.
 *
 * A component using the pfMixinSearchable mixin component is required to:
 *
 *   1. declare a property 'searchableOptions' with the following structure:
 *     - declare a property 'searchApiEndpoint' (string|function);
 *     - declare a property 'defaultSearchKeys' (array);
 *     - declare a property 'defaultSearchCondition' (object);
 *     - declare a property 'defaultRoute' (object);
 *
 *      export default {
 *        // ...
 *        props: {
 *          searchableOptions: {
 *            type: Object,
 *            default: {
 *              searchApiEndpoint: 'users',
 *              searchApiEndpointOnly: false,
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
 *   - implement a method name 'searchableInitCondition' (used when the search is reset or cleared).
 *   - implement a method name 'searchableQuickCondition' (used when predefining search fields in quick mode).
 *   - implement a method name 'searchableAdvancedMode' (used when determining if advanced mode is enabled).
 *
 */
import SearchableStore from '@/store/base/searchable'
import pfSearch from '@/components/pfSearch'

export default {
  name: 'pfMixinSearchable',
  components: {
    pfSearch
  },
  props: {
    searchableOptions: {
      type: Object,
      default: {
        searchApiEndpointOnly: false,
        defaultSearchCondition: () => {
          return { op: 'and', values: [{ op: 'or', values: [{ field: null, op: null, value: null }] }] }
        }
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
      pageSizeLimit: 25
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
      return [...(new Set([ // unique array
        ...this.searchableOptions.defaultSortKeys, // always include default keys
        ...this.visibleColumns.filter(column => !column.locked).map(column => column.key)
      ]))]
    },
    items () {
      if (this.searchableStoreName) {
        let results = this.$store.state[this.searchableStoreName].results
        if ('resultsFilter' in this.searchableOptions) {
          results = this.searchableOptions.resultsFilter(results)
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
      const { searchableOptions: { searchApiEndpoint = null } = {} } = this
      if (searchApiEndpoint) {
        return '$_' + searchApiEndpoint.replace(/[/]/g, '_').replace(/[-: ]/g, '') + '_searchable'
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
          this.searchableOptions.searchApiEndpoint,
          this.searchableOptions.defaultSortKeys,
          this.searchableOptions.defaultSortDesc || false,
          this.pageSizeLimit
        )
        this.$store.registerModule(this.searchableStoreName, searchableStore.module())
      }
      this.pageSizeLimit = this.$store.state[this.searchableStoreName].searchPageSize
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
        this.searchableInitCondition()
      } while (false)
    },
    onSearch (searchCondition = '') {
      if (!this.$store.state[this.searchableStoreName]) {
        this.initStore()
      }
      let condition = searchCondition
      if (!this.advancedMode && searchCondition.constructor === String && this.searchableQuickCondition.constructor === Function) {
        // Build quick search query
        condition = this.searchableQuickCondition(searchCondition)
      }
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this.searchableStoreName}/setSearchQuery`, condition)
      this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage).then(() => {
        this.currentPage = this.requestPage
        if (condition) {
          this.condition = condition
        }
      }).catch(() => {
        this.requestPage = this.currentPage
      })
      // pfMixinSelectable
      if (this.$options.methods.clearSelected) {
        this.clearSelected()
      }
    },
    onReset () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this.searchableStoreName}/setSearchQuery`, null) // reset search
      this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage).then(() => {
        this.currentPage = this.requestPage
        this.searchableInitCondition()
      }).catch(() => {
        this.requestPage = this.currentPage
      })
      const { searchableOptions: { defaultRoute } = {} } = this
      if (defaultRoute) {
        this.$router.push(defaultRoute)
      }
    },
    onImport (condition) {
      this.$set(this, 'condition', condition)
      const { searchableOptions: { defaultRoute } = {} } = this
      if (defaultRoute) {
        this.$router.push(Object.assign(defaultRoute, { query: { query: JSON.stringify(condition) } }))
      }
    },
    searchableInitCondition () {
      const { searchableOptions: { defaultSearchCondition = null } = {} } = this
      if (defaultSearchCondition) {
        this.$set(this, 'condition', { ...defaultSearchCondition }) // dereferenced copy
      }
    },
    onPageSizeChange () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch(`${this.searchableStoreName}/setSearchPageSize`, this.pageSizeLimit)
      this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage)
    },
    onPageChange () {
      this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage).then(() => {
        this.currentPage = this.requestPage
      }).catch(() => {
        this.requestPage = this.currentPage
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
    searchableOptions: {
      handler (a, b) {
        this.initStore()
        this.onSearch()
      }
    },
    $route: {
      handler (a, b) {
        const { query: { query: queryA } = {} } = a || {}
        const { query: { query: queryB } = {} } = b || {}
        if (!queryA && queryB === JSON.stringify(this.condition)) {
          this.onReset() // clear search
        } else if (queryA) {
          this.advancedMode = true
          const condition = JSON.parse(queryA)
          this.onSearch(condition) // submit search
        }
      },
      immediate: true
    },
    condition: {
      handler (a, b) {
        // clear if query param !== condition
        if (a && JSON.stringify(a) !== this.query) {
          this.$router.push({ query: null })
        }
        if (JSON.stringify(a) !== JSON.stringify(b)) {
          if (a === undefined || a === null) {
            // empty query, re-initialize
            this.searchableInitCondition()
          } else if (this.searchableAdvancedMode && this.searchableAdvancedMode.constructor === Function) {
            // enable advancedMode (if not already)
            this.advancedMode = (this.searchableAdvancedMode(a)) ? true : this.advancedMode
          }
        }
      },
      immediate: true,
      deep: true
    }
  },
  created () {
    // called before the component's created function.
    if (!this.fields) {
      throw new Error(`Missing 'fields' in data of component ${this.$options.name}`)
    }
    if (!this.columns) {
      throw new Error(`Missing 'columns' in data of component ${this.$options.name}`)
    }
    const { searchableOptions: { defaultRoute, defaultSortKeys, defaultSearchCondition, searchApiEndpoint } = {} } = this
    if (defaultRoute && defaultSortKeys && defaultSearchCondition && searchApiEndpoint) {
      this.initStore()
    }
  },
  mounted () {
    // called after the component's mounted function.
    const { searchableOptions: { defaultSearchCondition, searchApiEndpointOnly } = {} } = this
    if (!searchApiEndpointOnly && JSON.stringify(this.condition) === JSON.stringify(defaultSearchCondition)) {
      // query all w/o criteria
      this.$store.dispatch(`${this.searchableStoreName}/setSearchQuery`, null)
    } else {
      this.$store.dispatch(`${this.searchableStoreName}/setSearchQuery`, this.condition)
    }
    this.$store.dispatch(`${this.searchableStoreName}/search`, this.requestPage)
  }
}
