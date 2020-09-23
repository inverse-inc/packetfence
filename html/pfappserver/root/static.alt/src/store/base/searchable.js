/**
* Base searchable store module. Used by:
*   pfMixinSearchable
*/
import Vue from 'vue'
import apiCall from '@/utils/api'

const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

class SearchableApi {
  constructor (config, defaultSortKeys) {
    const { url = '/', headers = {} } = config
    this.url = url
    this.headers = headers
    this.defaultSortKeys = defaultSortKeys
  }
  all (params) {
    if (params.sort) {
      params.sort = params.sort.join(',')
    } else {
      params.sort = this.defaultSortKeys.join(',')
    }
    if (params.fields) {
      params.fields = params.fields.join(',')
    }
    return apiCall.get(this.url, { headers: this.headers, ...params }).then(response => {
      return response.data
    })
  }
  search (body) {
    return apiCall.post(`${this.url}/search`, body).then(response => {
      return response.data
    })
  }
  item (id) {
    return apiCall.get([ ...this.url.split('/'), id ]).then(response => {
      return response.data.item
    })
  }
}

export default class SearchableStore {
  constructor (url, headers, defaultSortKeys, defaultSortDesc = false, pageSizeLimit = 25) {
    this.storage_search_limit_key = url + '-search-limit'
    this.storage_visible_columns_key = url + '-visible-columns'
    this.defaultSortKeys = defaultSortKeys
    this.defaultSortDesc = defaultSortDesc
    this.pageSizeLimit = ~~pageSizeLimit
    this.api = new SearchableApi({ url, headers }, defaultSortKeys)
  }

  module () {
    const state = () => {
      return {
        results: [], // search results
        cache: Vue.observable({}), // items details
        extraFields: {},
        message: '',
        itemStatus: '',
        searchStatus: '',
        searchFields: [],
        searchQuery: null,
        searchSortBy: this.defaultSortKeys[0],
        searchSortDesc: this.defaultSortDesc,
        searchMaxPageNumber: 1,
        searchPageSize: ~~(localStorage.getItem(this.storage_search_limit_key) || this.pageSizeLimit),
        visibleColumns: JSON.parse(localStorage.getItem(this.storage_visible_columns_key)) || false
      }
    }

    const getters = {
      isLoading: state => state.itemStatus === types.LOADING,
      isLoadingResults: state => state.searchStatus === types.LOADING
    }

    const actions = {
      setExtraFields: ({ commit }, fields) => {
        commit('EXTRA_FIELDS_UPDATED', fields)
      },
      setSearchFields: ({ commit }, fields) => {
        commit('SEARCH_FIELDS_UPDATED', fields)
      },
      setSearchQuery: ({ commit }, query) => {
        commit('SEARCH_QUERY_UPDATED', query)
        commit('SEARCH_MAX_PAGE_NUMBER_UPDATED', 1) // reset page count
      },
      setSearchPageSize: ({ commit }, limit) => {
        localStorage.setItem(this.storage_search_limit_key, limit)
        commit('SEARCH_LIMIT_UPDATED', limit)
        commit('SEARCH_MAX_PAGE_NUMBER_UPDATED', 1) // reset page count
      },
      setSearchSorting: ({ commit }, params) => {
        commit('SEARCH_SORT_BY_UPDATED', params.sortBy)
        commit('SEARCH_SORT_DESC_UPDATED', params.sortDesc)
        commit('SEARCH_MAX_PAGE_NUMBER_UPDATED', 1) // reset page count
      },
      setVisibleColumns: ({ commit }, columns) => {
        localStorage.setItem(this.storage_visible_columns_key, JSON.stringify(columns))
        commit('VISIBLE_COLUMNS_UPDATED', columns)
      },
      search: ({ state, commit }, page) => {
        let body = {
          ...{
            cursor: state.searchPageSize * (page - 1),
            limit: state.searchPageSize,
            fields: state.searchFields,
            // append sort only if searchSortBy is defined
            ...((state.searchSortBy)
              ? {
                sort: [state.searchSortDesc ? `${state.searchSortBy} DESC` : state.searchSortBy]
              }
              : {}
            )
          },
          ...state.extraFields
        }
        let apiPromise = state.searchQuery ? this.api.search(Object.assign(body, { query: state.searchQuery })) : this.api.all(body)
        if (state.searchStatus !== types.LOADING) {
          commit('SEARCH_REQUEST')
          return new Promise((resolve, reject) => {
            apiPromise.then(response => {
              commit('SEARCH_SUCCESS', response)
              resolve(response)
            }).catch(err => {
              commit('SEARCH_ERROR', err.response)
              reject(err)
            })
          })
        }
      },
      setResultSorting: ({ state, commit }, event) => {
        commit('ITEMS_SORTED', event)
        return state.results
      },
      getItem: ({ state, commit }, id) => {
        if (state.cache[id]) {
          return Promise.resolve(state.cache[id])
        }
        commit('ITEM_REQUEST')
        return this.api.item(id).then(data => {
          commit('ITEM_REPLACED', data)
          return state.cache[id]
        }).catch(err => {
          commit('ITEM_ERROR', err.response)
          return err
        })
      },
      updateItem: ({ commit }, params) => {
        commit('ITEM_UPDATED', params)
      }
    }

    const mutations = {
      EXTRA_FIELDS_UPDATED: (state, fields) => {
        state.extraFields = fields
      },
      SEARCH_FIELDS_UPDATED: (state, fields) => {
        state.searchFields = fields
      },
      SEARCH_QUERY_UPDATED: (state, query) => {
        state.searchQuery = query
      },
      SEARCH_SORT_BY_UPDATED: (state, field) => {
        state.searchSortBy = field
      },
      SEARCH_SORT_DESC_UPDATED: (state, desc) => {
        state.searchSortDesc = desc
      },
      SEARCH_MAX_PAGE_NUMBER_UPDATED: (state, page) => {
        state.searchMaxPageNumber = page
      },
      SEARCH_LIMIT_UPDATED: (state, limit) => {
        state.searchPageSize = ~~limit
      },
      SEARCH_REQUEST: (state) => {
        state.searchStatus = types.LOADING
      },
      SEARCH_SUCCESS: (state, response) => {
        state.searchStatus = types.SUCCESS
        if (response) {
          const { items = [], nextCursor, total_count: totalCount } = response
          Vue.set(state, 'results', [ ...(items || []).filter(item => item.not_sortable), ...(items || []).filter(item => !item.not_sortable) ])
          let nextPage = Math.floor(nextCursor / state.searchPageSize) + 1
          if (totalCount) {
            state.searchMaxPageNumber = Math.ceil(totalCount / state.searchPageSize)
          } else if (nextPage > state.searchMaxPageNumber) {
            state.searchMaxPageNumber = nextPage
          }
        }
      },
      SEARCH_ERROR: (state, response) => {
        state.searchStatus = types.ERROR
        if (response && response.data) {
          state.message = response.data.message
        }
      },
      VISIBLE_COLUMNS_UPDATED: (state, columns) => {
        state.visibleColumns = columns
      },
      ITEMS_SORTED: (state, event) => {
        const { oldIndex, newIndex } = event // shifted, not swapped
        let results = JSON.parse(JSON.stringify(state.results))
        const tmp = results[oldIndex]
        if (oldIndex > newIndex) {
          // shift down (not swapped)
          for (let i = oldIndex; i > newIndex; i--) {
            results[i] = results[i - 1]
          }
        } else {
          // shift up (not swapped)
          for (let i = oldIndex; i < newIndex; i++) {
            results[i] = results[i + 1]
          }
        }
        results[newIndex] = tmp
        Vue.set(state, 'results', results)
      },
      ITEM_REQUEST: (state) => {
        state.itemStatus = types.LOADING
        state.message = ''
      },
      ITEM_REPLACED: (state, data) => {
        state.itemStatus = types.SUCCESS
        Vue.set(state.cache, data.id, data)
      },
      ITEM_ERROR: (state, response) => {
        state.itemStatus = types.ERROR
        if (response && response.data) {
          state.message = response.data.message
        }
      },
      ITEM_UPDATED: (state, params) => {
        let index = state.results.findIndex(result => result[params.key] === params[params.key])
        if (index in state.results) {
          Vue.set(state.results[index], params.prop, params.data)
        }
        if (state.cache[params[params.key]]) {
          Vue.set(state.cache[params[params.key]], params.prop, params.data)
        }
      }
    }

    return {
      namespaced: true,
      state,
      getters,
      actions,
      mutations
    }
  }
}
