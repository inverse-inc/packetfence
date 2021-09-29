import { defineStore } from 'pinia'
import { createDebouncer } from 'promised-debounce'
import i18n from '@/utils/locale'
import { toKebabCase } from '@/utils/strings'

const useColumns = (columns) => {
  return columns
    .filter(column => column.searchable)
}

const useFields = (columns) => {
  return columns
    .filter(column => (column.required || column.visible) && !column.locked)
    .map(column => column.key)
}

export const useString = (searchString, columns) => {
  return {
    op: 'and',
    values: [{
      op: 'or',
      values: columns.map(column => ({
        field: column.key,
        op: 'contains',
        value: searchString.trim()
      }))
    }]
  }
}

const factory = (uuid, options = {}) => {
  const id = `$_${toKebabCase(uuid, '_')}_search`
  return defineStore({
    id,
    state() {
      return {
        uuid,
        // defaults
        api: {
          list: (new Promise(r => r())),
          search: (new Promise(r => r()))
        },
        columns: [],
        fields: [],
        page: 1,
        sortBy: null, // use natural order
        sortDesc: false,
        limit: 25,
        limits: [10, 25, 50, 100, 200, 500, 1000],
        defaultCondition: () => ({ op: 'and', values: [
          { op: 'or', values: [
            { field: 'id', op: 'not_equals', value: null }
          ] }
        ] }),
        requestInterceptor: (request) => request,
        responseInterceptor: (response) => response,
        errorInterceptor: (error) => { throw (error) },
        useColumns,
        useFields,
        useString,
        useCondition: condition => condition,

        // overload defaults
        ...options,

        // local
        isLoading: false,
        lastQuery: null,
        items: [],
        totalRows: 0,

        // api debouncer
        $debouncer: createDebouncer(),
        $debouncerMs: 100, // 100ms
      }
    },
    getters: {
      visibleColumns: state => state.columns
        .filter(column => (column.locked || column.visible))
        .map(column => ({ ...column, label: i18n.t(column.label) })), // transliterate label
      titleBasic: state => {
        const [last, ...csv] = state.columns
          .filter(column => column.searchable)
          .map(column => i18n.t(column.label))
          .reverse()
        if (csv.length) {
          return i18n.t('Search criteria for "{csv}" or "{last}"', { csv: csv.reverse().join('", "'), last })
        } else {
          return i18n.t('Search criteria for "{only}"', { only: last })
        }
      }
    },
    actions: {
      setUp({ columns, limit, page, sortBy, sortDesc }) {
        if (columns)
          this.columns = this.columns.map(c => ({ ...c, visible: columns.includes(c.key) }))
        if (limit)
          this.limit = limit
        if (page)
          this.page = page
        if (sortBy || sortDesc) {
          this.sortBy = sortBy
          this.sortDesc = sortDesc
        }
      },
      setColumns(columns) {
        this.columns = columns
        this.reSearch()
      },
      setLimit(limit) {
        if (+limit !== this.limit) {
          this.limit = +limit
          this.page = 1
          this.reSearch()
        }
      },
      setPage(page) {
        this.page = +page
        this.reSearch()
      },
      setSort(sort) {
        const { sortBy, sortDesc } = sort
        this.sortBy = sortBy
        this.sortDesc = !!sortDesc
        this.reSearch()
      },
      doReset() {
        this.isLoading = true
        const fields = this.useFields(this.columns).join(',')
        const params = {
          fields,
          sort: ((this.sortBy)
            ? ((this.sortDesc)
              ? `${this.sortBy} DESC`
              : `${this.sortBy}`
            )
            : null // use natural sort
          ),
          limit: this.limit,
          cursor: ((this.page * this.limit) - this.limit)
        }
        if ('list' in this.api) { // has api.list
          this.$debouncer({
            handler: () => {
              return this.api.list(params)
                .then(_response => {
                  const response = this.responseInterceptor(_response)
                  const { items = [], total_count } = response
                  this.items = items || []
                  if (total_count) // endpoint returned a total count
                    this.totalRows = total_count
                  else if (items.length === this.limit) // +1 to guarantee next
                    this.totalRows = (this.page * this.limit) + 1
                  else
                    this.totalRows = (this.page * this.limit) - this.limit + items.length
                  this.lastQuery = null
                })
                .catch(() => {
                  this.items = []
                  this.totalRows = 0
                  this.lastQuery = null
                })
                .finally(() => {
                  this.isLoading = false
                })
            },
            time: this.$debouncerMs
          })
        }
        else // no api.list
          return this.doSearchCondition(this.defaultCondition())
      },
      doSearchString(string) {
        const columns = this.useColumns(this.columns, this.fields)
        const query = this.useString(string, columns)
        return this.doSearch(query)
      },
      doSearchCondition(condition) {
        const columns = this.useColumns(this.columns, this.fields)
        const query = this.useCondition(condition, columns)
        return this.doSearch(query)
      },
      doSearch(query) {
        this.isLoading = true
        const fields = this.useFields(this.columns)
        const _body = {
          fields,
          query,
          sort: ((this.sortBy)
            ? ((this.sortDesc)
              ? [`${this.sortBy} DESC`]
              : [`${this.sortBy}`]
            )
            : null // use natural sort
          ),
          limit: this.limit,
          cursor: ((this.page * this.limit) - this.limit)
        }
        const body = this.requestInterceptor(_body)
        this.$debouncer({
          handler: () => {
            return this.api.search(body)
              .then(_response => {
                const response = this.responseInterceptor(_response)
                const { items, total_count } = response
                this.items = items || []
                if (total_count) // endpoint returned a total count
                  this.totalRows = total_count
                else if (items.length === this.limit) // +1 to guarantee next
                  this.totalRows = (this.page * this.limit) + 1
                else
                  this.totalRows = (this.page * this.limit) - this.limit + items.length
                this.lastQuery = query
              })
              .catch(() => {
                this.items = []
                this.totalRows = 0
                this.lastQuery = null
              })
              .finally(() => {
                this.isLoading = false
              })
          },
          time: this.$debouncerMs
        })
      },
      reSearch() {
        const visibleSortBy = (this.columns || [])
          .find(c => c.visible && c.key == this.sortBy)
        if (!visibleSortBy) {
          const sortable = (this.columns || [])
            .find(c => c.required && c.sortable)
          if (sortable) {
            this.sortBy = sortable['key']
            this.sortDesc = false
          }
        }
        if (this.lastQuery) // last query good
          return this.doSearch(this.lastQuery) // re-perform search w/ last query
        else
          return this.doReset()
      }
    }
  })
}

export default factory
