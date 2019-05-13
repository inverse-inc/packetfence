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
  constructor (endpoint, defaultSortKeys) {
    this.endpoint = endpoint
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
    return apiCall.get(this.endpoint, { params }).then(response => {
      return response.data
    })
  }
  search (body) {
    return apiCall.post(`${this.endpoint}/search`, body).then(response => {
      return response.data
    })
  }
  item (id) {
    return apiCall.get(`${this.endpoint}/${id}`).then(response => {
      return response.data.item
    })
  }
}

export default class SearchableStore {
  constructor (apiEndpoint, defaultSortKeys, defaultSortDesc = false, pageSizeLimit = 25) {
    this.storage_search_limit_key = apiEndpoint + '-search-limit'
    this.storage_visible_columns_key = apiEndpoint + '-visible-columns'
    this.defaultSortKeys = defaultSortKeys
    this.defaultSortDesc = defaultSortDesc
    this.pageSizeLimit = pageSizeLimit
    this.api = new SearchableApi(apiEndpoint, defaultSortKeys)
  }

  module () {
    let _this = this
    const state = () => {
      return {
        results: [], // search results
        cache: {}, // items details
        extraFields: {},
        message: '',
        itemStatus: '',
        searchStatus: '',
        searchFields: [],
        searchQuery: null,
        searchSortBy: _this.defaultSortKeys[0],
        searchSortDesc: _this.defaultSortDesc,
        searchMaxPageNumber: 1,
        searchPageSize: localStorage.getItem(_this.storage_search_limit_key) || _this.pageSizeLimit,
        visibleColumns: JSON.parse(localStorage.getItem(_this.storage_visible_columns_key)) || false
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
        localStorage.setItem(_this.storage_search_limit_key, limit)
        commit('SEARCH_LIMIT_UPDATED', limit)
        commit('SEARCH_MAX_PAGE_NUMBER_UPDATED', 1) // reset page count
      },
      setSearchSorting: ({ commit }, params) => {
        commit('SEARCH_SORT_BY_UPDATED', params.sortBy)
        commit('SEARCH_SORT_DESC_UPDATED', params.sortDesc)
        commit('SEARCH_MAX_PAGE_NUMBER_UPDATED', 1) // reset page count
      },
      setVisibleColumns: ({ commit }, columns) => {
        localStorage.setItem(_this.storage_visible_columns_key, JSON.stringify(columns))
        commit('VISIBLE_COLUMNS_UPDATED', columns)
      },
      search: ({ state, getters, commit, dispatch }, page) => {
        let sort = [state.searchSortDesc ? `${state.searchSortBy} DESC` : state.searchSortBy]
        let body = {
          ...{
            cursor: state.searchPageSize * (page - 1),
            limit: state.searchPageSize,
            fields: state.searchFields,
            sort
          },
          ...state.extraFields
        }
        let apiPromise = state.searchQuery ? _this.api.search(Object.assign(body, { query: state.searchQuery })) : _this.api.all(body)
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
        const { oldIndex, newIndex } = event // shifted, not swapped
        let sortableResults = state.results.filter(item => !item.not_sortable)
        const tmp = sortableResults[oldIndex]
        if (oldIndex > newIndex) {
          // shift down (not swapped)
          for (let i = oldIndex; i > newIndex; i--) {
            sortableResults[i] = sortableResults[i - 1]
          }
        } else {
          // shift up (not swapped)
          for (let i = oldIndex; i < newIndex; i++) {
            sortableResults[i] = sortableResults[i + 1]
          }
        }
        sortableResults[newIndex] = tmp
        const results = [ ...state.results.filter(item => item.not_sortable), ...sortableResults ]
        commit('ITEMS_SORTED', results)
        return state.results
      },
      getItem: ({ state, commit }, id) => {
        if (state.cache[id]) {
          return Promise.resolve(state.cache[id])
        }
        commit('ITEM_REQUEST')
        return _this.api.item(id).then(data => {
          commit('ITEM_REPLACED', data)
          return state.cache[id]
        }).catch(err => {
          commit('ITEM_ERROR', err.response)
          return err
        })
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
        state.searchPageSize = limit
      },
      SEARCH_REQUEST: (state) => {
        state.searchStatus = types.LOADING
      },
      SEARCH_SUCCESS: (state, response) => {
        state.searchStatus = types.SUCCESS
        if (response) {
          state.results = [ ...response.items.filter(item => item.not_sortable), ...response.items.filter(item => !item.not_sortable) ]
          let nextPage = Math.floor(response.nextCursor / state.searchPageSize) + 1
          if (nextPage > state.searchMaxPageNumber) {
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
      ITEMS_SORTED: (state, data) => {
        Vue.set(state, 'results', data)
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
