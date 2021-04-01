import { computed, ref, watch } from '@vue/composition-api'
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

export const useString = (searchString, _columns) => {
  const columns = useColumns(_columns)
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
    values: searchCondition.map(and => {
      return {
        op: 'or',
        values: and.values
      }
    })
  }
}

export const useSearch = (api, options) => {

  const config = {
    // defaults
    columns: [],
    fields: [],
    sortBy: 'id',
    sortDesc: false,
    limit: 25,
    limits: [25, 50, 100, 200, 500, 1000],
    requestInterceptor: (request) => request,
    responseInterceptor: (response) => response,
    errorInterceptor: (error) => { throw (error) },
    useColumns,
    useFields,

    // overload
    ...options,
  }

  const columns = ref(config.columns)
  const visibleColumns = computed(() => {
    return columns.value
      .filter(column => (column.locked || column.visible))
      .map(column => ({ ...column, label: i18n.t(column.label) })) // transliterate label
  })
  const fields = ref(config.fields)
  const sortBy = ref(config.sortBy)
  const sortDesc = ref(config.sortDesc)
  const onSortChanged = params => {
    const { sortBy: _sortBy, sortDesc: _sortDesc } = params
    sortBy.value = _sortBy
    sortDesc.value = _sortDesc
  }

  const limit = ref(config.limit)
  const limits = ref(config.limits)

  const page = ref(1)
  const isLoading = ref(false)
  const lastQuery = ref(null)
  const items = ref([])
  const totalRows = ref(0)

  const doReset = () => {
    const fields = useFields(columns.value).join(',')
    const params = {
      fields,
      sort: ((sortDesc.value)
        ? `${sortBy.value} DESC`
        : `${sortBy.value}`
      ),
      limit: limit.value,
      cursor: ((page.value * limit.value) - limit.value)
    }
    isLoading.value = true
    api.list(params)
      .then(_response => {
        const response = config.responseInterceptor(_response)
        const { items: _items = [], total_count } = response
        items.value = _items
        totalRows.value = total_count
        lastQuery.value = null
        return response
      })
      .catch(() => {
        items.value = []
        page.value = 1
        totalRows.value = 0
        lastQuery.value = null
      })
      .finally(() => {
        isLoading.value = false
      })
  }

  const doSearchString = (string) => {
    return doSearch(useString(string, columns.value))
  }
  const doSearchCondition = (condition)=> {
    return doSearch(useCondition(condition, columns.value))
  }
  const doSearch = (query) => {
    const fields = useFields(columns.value)
    const _body = {
      fields,
      query,
      sort: ((sortDesc.value)
        ? [`${sortBy.value} DESC`]
        : [`${sortBy.value}`]
      ),
      limit: limit.value,
      cursor: ((page.value * limit.value) - limit.value)
    }
    const body = config.requestInterceptor(_body)
    isLoading.value = true
    api.search(body)
      .then(_response => {
        const response = config.responseInterceptor(_response)
        const { items: _items = [], total_count } = response
        items.value = _items
        page.value = 1
        totalRows.value = total_count
        lastQuery.value = query
        return response
      })
      .catch(() => {
        items.value = []
        page.value = 1
        totalRows.value = 0
        lastQuery.value = null
      })
      .finally(() => {
        isLoading.value = false
      })
  }

  const reSearch = () => {
    const visibleSortBy = columns.value.find(c => c.key == sortBy.value && c.visible)
    if (!visibleSortBy) {
      onSortChanged({
        sortBy: columns.value.find(c => c.required)['key'],
        sortDesc: false
      })
    }
    if (lastQuery.value) // last query good
      doSearch(lastQuery.value) // re-perform search w/ last query
    else
      doReset()
  }

  // when limit is mutated
  watch(limit, () => {
    page.value = 1
    reSearch()
  })

  // when page, sortBy or sortDesc is mutated (shallow)
  watch([page, sortBy, sortDesc], () => reSearch())

  // when columns are mutated (deep)
  watch(columns, () => reSearch(), { deep: true })

  return {
    columns,
    visibleColumns,
    fields,
    sortBy,
    sortDesc,
    onSortChanged,
    limit,
    limits,
    page,
    totalRows,
    doReset,
    doSearchString,
    doSearchCondition,
    doSearch,
    reSearch,
    isLoading,
    items,

    useString
  }
}

export default {
  useSearch
}
