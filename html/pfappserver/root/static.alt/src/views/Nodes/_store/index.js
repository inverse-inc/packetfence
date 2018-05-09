/**
 * "$_nodes" store module
 */
import Vue from 'vue'
import api from '../_api'

const STORAGE_SEARCH_LIMIT_KEY = 'nodes-search-limit'

// Default values
const state = {
  status: '',
  items: [],
  nodes: {},
  searchQuery: null,
  searchSortBy: 'mac',
  searchSortDesc: false,
  searchMaxPageNumber: 1,
  searchPageSize: localStorage.getItem(STORAGE_SEARCH_LIMIT_KEY) || 10
}

const getters = {
  isLoading: state => state.status === 'loading'
}

const actions = {
  setSearchQuery: ({commit}, query) => {
    commit('SEARCH_QUERY_UPDATED', query)
    commit('SEARCH_MAX_PAGE_NUMBER_UPDATED', 1) // reset page count
  },
  setSearchPageSize: ({commit}, limit) => {
    localStorage.setItem(STORAGE_SEARCH_LIMIT_KEY, limit)
    commit('SEARCH_LIMIT_UPDATED', limit)
    commit('SEARCH_MAX_PAGE_NUMBER_UPDATED', 1) // reset page count
  },
  setSearchSorting: ({commit}, params) => {
    commit('SEARCH_SORT_BY_UPDATED', params.sortBy)
    commit('SEARCH_SORT_DESC_UPDATED', params.sortDesc)
    commit('SEARCH_MAX_PAGE_NUMBER_UPDATED', 1) // reset page count
  },
  search: ({state, getters, commit, dispatch}, page) => {
    let sort = [state.searchSortDesc ? `${state.searchSortBy} DESC` : state.searchSortBy]
    let body = {
      cursor: state.searchPageSize * (page - 1),
      limit: state.searchPageSize,
      sort
    }
    let apiPromise = state.searchQuery ? api.search(Object.assign(body, {query: state.searchQuery})) : api.all(body)
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
  },
  getNode: ({commit}, mac) => {
    let node = {} // ip4: { history: [] }, ip6: { history: [] } }

    return api.node(mac).then(item => {
      Object.assign(node, item)
      commit('NODE_REPLACED', node)

      // Fetch ip4log history
      let ip4 = {}
      api.ip4logOpen(mac).then(item => {
        Object.assign(ip4, item)
        ip4.active = item.end_time === '0000-00-00 00:00:00'
      }).catch(() => {
        Object.assign(ip4, { active: false })
      }).finally(() => {
        api.ip4logHistory(mac).then(items => {
          if (items && items.length > 0) {
            Object.assign(ip4, { history: items })
            if (!ip4.active && !ip4.end_time) {
              ip4.end_time = items[0].end_time
            }
          }
        }).catch(() => {
          // noop
        }).finally(() => {
          commit('NODE_UPDATED', { mac, prop: 'ip4', data: ip4 })
        })
      })

      // Fetch ip6log history
      let ip6 = {}
      api.ip6logOpen(mac).then(item => {
        Object.assign(ip6, item)
        ip6.active = item.end_time === '0000-00-00 00:00:00'
      }).catch(() => {
        Object.assign(ip6, { active: false })
      }).finally(() => {
        api.ip6logHistory(mac).then(items => {
          if (items && items.length > 0) {
            Object.assign(ip6, { history: items })
            if (!ip6.active && !ip6.end_time) {
              ip6.end_time = items[0].end_time
            }
          }
        }).catch(() => {
          // noop
        }).finally(() => {
          commit('NODE_UPDATED', { mac, prop: 'ip6', data: ip6 })
        })
      })

      // Fetch locationlogs
      api.locationlogs(mac).then(items => {
        commit('NODE_UPDATED', { mac, prop: 'locations', data: items })
      })

      // Fetch violations
      api.violations(mac).then(items => {
        commit('NODE_UPDATED', { mac, prop: 'violations', data: items })
      })

      return node
    })
  }
}

const mutations = {
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
    state.status = 'loading'
  },
  SEARCH_SUCCESS: (state, response) => {
    state.status = 'success'
    state.items = response.items
    let nextPage = Math.floor(response.nextCursor / state.searchPageSize) + 1
    if (nextPage > state.searchMaxPageNumber) {
      state.searchMaxPageNumber = nextPage
    }
  },
  SEARCH_ERROR: (state, response) => {
    state.status = 'error'
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  NODE_REPLACED: (state, data) => {
    Vue.set(state.nodes, data.mac, data)
  },
  NODE_UPDATED: (state, params) => {
    Vue.set(state.nodes[params.mac], params.prop, params.data)
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
