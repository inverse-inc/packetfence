import { defineStore } from 'pinia'
import i18n from '@/utils/locale'

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

export const useCondition = (searchCondition) => {
  return {
    op: 'and',
    values: searchCondition.map(or => {
      return {
        op: 'or',
        values: or.values
      }
    })
  }
}

const factory = (id, options = {}) => defineStore({
  id,
  state() {
    return {
      // defaults
      api: {
        list: (new Promise(r => r())),
        search: (new Promise(r => r()))
      },
      columns: [],
      fields: [],
      page: 1,
      sortBy: 'id',
      sortDesc: false,
      limit: 25,
      limits: [25, 50, 100, 200, 500, 1000],
      defaultCondition: () => ([{ values: [] }]),
      requestInterceptor: (request) => request,
      responseInterceptor: (response) => response,
      errorInterceptor: (error) => { throw (error) },
      useColumns,
      useFields,
      useString,
      useCondition,

      // overload defaults
      ...options,

      // custom
      isLoading: false,
      lastQuery: null,
      items: [],
      totalRows: 0
    }
  },
  getters: {
    visibleColumns: state => state.columns
      .filter(column => (column.locked || column.visible))
      .map(column => ({ ...column, label: i18n.t(column.label) })), // transliterate label
  },
  actions: {
    setColumns(columns) {
      this.columns = columns
      this.reSearch()
    },
    setLimit(limit) {
      this.limit = limit
      this.reSearch()
    },
    setPage(page) {
      this.page = page
      this.reSearch()
    },
    setSort(sort) {
      const { sortBy, sortDesc } = sort
      this.sortBy = sortBy
      this.sortDesc = sortDesc
      this.reSearch()
    },
    doReset() {
      const fields = this.useFields(this.columns).join(',')
      const params = {
        fields,
        sort: ((this.sortDesc)
          ? `${this.sortBy} DESC`
          : `${this.sortBy}`
        ),
        limit: this.limit,
        cursor: ((this.page * this.limit) - this.limit)
      }
      this.isLoading = true
      this.api.list(params)
        .then(_response => {
          const response = this.responseInterceptor(_response)
          const { items = [], total_count } = response
          this.items = items
          this.totalRows = total_count
          this.lastQuery = null
        })
        .catch(() => {
          this.page = 1
          this.items = []
          this.totalRows = 0
          this.lastQuery = null
        })
        .finally(() => {
          this.isLoading = false
        })
    },
    doSearchString(string) {
      const columns = this.useColumns(this.columns)
      const query = this.useString(string, columns)
      return this.doSearch(query)
    },
    doSearchCondition(condition) {
      const columns = this.useColumns(this.columns)
      const query = this.useCondition(condition, columns)
      return this.doSearch(query)
    },
    doSearch(query) {
      const fields = this.useFields(this.columns)
      const _body = {
        fields,
        query,
        sort: ((this.sortDesc)
          ? [`${this.sortBy} DESC`]
          : [`${this.sortBy}`]
        ),
        limit: this.limit,
        cursor: ((this.page * this.limit) - this.limit)
      }
      const body = this.requestInterceptor(_body)
      this.isLoading = true
      this.api.search(body)
        .then(_response => {
          const response = this.responseInterceptor(_response)
          const { items = [], total_count } = response
          this.page = 1
          this.items = items
          this.totalRows = total_count
          this.lastQuery = query
        })
        .catch(() => {
          this.page = 1
          this.items = []
          this.totalRows = 0
          this.lastQuery = null
        })
        .finally(() => {
          this.isLoading = false
        })
    },
    reSearch() {
      const visibleSortBy = this.columns.find(c => c.visible && c.key == this.sortBy)
      if (!visibleSortBy) {
        this.setSort({
          sortBy: this.columns.find(c => c.required)['key'],
          sortDesc: false
        })
      }
      if (this.lastQuery) // last query good
        this.doSearch(this.lastQuery) // re-perform search w/ last query
      else
        this.doReset()
    }
  }
})

export default factory
