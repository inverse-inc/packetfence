import { defineStore } from 'pinia'
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
        sortBy: 'id',
        sortDesc: false,
        limit: 25,
        limits: [10, 25, 50, 100, 200, 500, 1000],
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

        // local
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
      placeholderBasic: state => {
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
          sort: ((this.sortDesc)
            ? `${this.sortBy} DESC`
            : `${this.sortBy}`
          ),
          limit: this.limit,
          cursor: ((this.page * this.limit) - this.limit)
        }
        this.api.list(params)
          .then(_response => {
            const response = this.responseInterceptor(_response)
            const { items = [], total_count } = response
            this.items = items
            this.totalRows = total_count
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
        this.isLoading = true
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
        this.api.search(body)
          .then(_response => {
            const response = this.responseInterceptor(_response)
            const { items = [], total_count } = response
            this.items = items
            this.totalRows = total_count
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
      reSearch() {
        const visibleSortBy = this.columns.find(c => c.visible && c.key == this.sortBy)
        if (!visibleSortBy) {
          this.sortBy = this.columns.find(c => c.required)['key']
          this.sortDesc = false
        }
        if (this.lastQuery) // last query good
          this.doSearch(this.lastQuery) // re-perform search w/ last query
        else
          this.doReset()
      }
    }
  })
}

export default factory
