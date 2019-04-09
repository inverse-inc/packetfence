/**
* "$_radiuslogs" store module
*/
import Vue from 'vue'
import api from '../_api'

const STORAGE_SEARCH_LIMIT_KEY = 'radiuslogs-search-limit'
const STORAGE_VISIBLE_COLUMNS_KEY = 'radiuslogs-visible-columns'

// Default values
const state = {
  results: [], // search results
  cache: {}, // radius log details
  message: '',
  itemStatus: '',
  searchStatus: '',
  searchFields: [],
  searchQuery: null,
  searchSortBy: 'mac',
  searchSortDesc: false,
  searchMaxPageNumber: 1,
  searchPageSize: localStorage.getItem(STORAGE_SEARCH_LIMIT_KEY) || 10,
  visibleColumns: JSON.parse(localStorage.getItem(STORAGE_VISIBLE_COLUMNS_KEY)) || false
}

const getters = {
  isLoading: state => state.itemStatus === 'loading',
  isLoadingResults: state => state.searchStatus === 'loading'
}

const actions = {
  setSearchFields: ({ commit }, fields) => {
    commit('SEARCH_FIELDS_UPDATED', fields)
  },
  setSearchQuery: ({ commit }, query) => {
    commit('SEARCH_QUERY_UPDATED', query)
    commit('SEARCH_MAX_PAGE_NUMBER_UPDATED', 1) // reset page count
  },
  setSearchPageSize: ({ commit }, limit) => {
    localStorage.setItem(STORAGE_SEARCH_LIMIT_KEY, limit)
    commit('SEARCH_LIMIT_UPDATED', limit)
    commit('SEARCH_MAX_PAGE_NUMBER_UPDATED', 1) // reset page count
  },
  setSearchSorting: ({ commit }, params) => {
    commit('SEARCH_SORT_BY_UPDATED', params.sortBy)
    commit('SEARCH_SORT_DESC_UPDATED', params.sortDesc)
    commit('SEARCH_MAX_PAGE_NUMBER_UPDATED', 1) // reset page count
  },
  setVisibleColumns: ({ commit }, columns) => {
    localStorage.setItem(STORAGE_VISIBLE_COLUMNS_KEY, JSON.stringify(columns))
    commit('VISIBLE_COLUMNS_UPDATED', columns)
  },
  search: ({ state, getters, commit, dispatch }, page) => {
    let sort = [state.searchSortDesc ? `${state.searchSortBy} DESC` : state.searchSortBy]
    let body = {
      cursor: state.searchPageSize * (page - 1),
      limit: state.searchPageSize,
      fields: state.searchFields,
      sort
    }
    let apiPromise = state.searchQuery ? api.search(Object.assign(body, { query: state.searchQuery })) : api.all(body)
    if (state.searchStatus !== 'loading') {
      return new Promise((resolve, reject) => {
        commit('SEARCH_REQUEST')
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
  getItem: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id])
    }
    commit('ITEM_REQUEST')
    return api.radiuslog(id).then(data => {
      commit('ITEM_REPLACED', data)
      return state.cache[id]
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      return err
    })
  }
}

const mutations = {
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
    state.searchStatus = 'loading'
  },
  SEARCH_SUCCESS: (state, response) => {
    state.searchStatus = 'success'
    if (response) {
      state.results = response.items
      let nextPage = Math.floor(response.nextCursor / state.searchPageSize) + 1
      if (nextPage > state.searchMaxPageNumber) {
        state.searchMaxPageNumber = nextPage
      }
    }
  },
  SEARCH_ERROR: (state, response) => {
    state.searchStatus = 'error'
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  VISIBLE_COLUMNS_UPDATED: (state, columns) => {
    state.visibleColumns = columns
  },
  ITEM_REQUEST: (state) => {
    state.itemStatus = 'loading'
    state.message = ''
  },
  ITEM_REPLACED: (state, data) => {
    state.itemStatus = 'success'
    Vue.set(state.cache, data.id, data)
  },
  ITEM_ERROR: (state, response) => {
    state.itemStatus = 'error'
    if (response && response.data) {
      state.message = response.data.message
    }
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
