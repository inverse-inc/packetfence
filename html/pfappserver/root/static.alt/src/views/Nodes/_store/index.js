/**
 * "$_nodes" store module
 */
import Vue from 'vue'
import api from '../_api'

const STORAGE_SEARCH_LIMIT_KEY = 'nodes-search-limit'

// Default values
const state = {
  items: [], // search results
  nodes: {}, // nodes details
  message: '',
  nodeStatus: '',
  searchStatus: '',
  searchQuery: null,
  searchSortBy: 'mac',
  searchSortDesc: false,
  searchMaxPageNumber: 1,
  searchPageSize: localStorage.getItem(STORAGE_SEARCH_LIMIT_KEY) || 10
}

const getters = {
  isLoading: state => state.nodeStatus === 'loading',
  isLoadingResults: state => state.searchStatus === 'loading'
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
      if (node.category_id === null) {
        node.category_id = 'unreg'
      }
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
  },
  createNode: ({commit}, data) => {
    commit('NODE_REQUEST')
    if (data.unreg_date && data.unreg_time) {
      data.unregdate = `${data.unreg_date} ${data.unreg_time}`
    }
    return new Promise((resolve, reject) => {
      api.createNode(data).then(response => {
        commit('NODE_REPLACED', data)
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  updateNode: ({commit}, data) => {
    commit('NODE_REQUEST')
    return new Promise((resolve, reject) => {
      api.updateNode(data).then(response => {
        commit('NODE_REPLACED', data)
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  deleteNode: ({commit}, mac) => {
    commit('NODE_REQUEST')
    return new Promise((resolve, reject) => {
      api.deleteNode(mac).then(response => {
        commit('NODE_DESTROYED', mac)
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
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
    state.searchStatus = 'loading'
  },
  SEARCH_SUCCESS: (state, response) => {
    state.searchStatus = 'success'
    state.items = response.items
    let nextPage = Math.floor(response.nextCursor / state.searchPageSize) + 1
    if (nextPage > state.searchMaxPageNumber) {
      state.searchMaxPageNumber = nextPage
    }
  },
  SEARCH_ERROR: (state, response) => {
    state.searchStatus = 'error'
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  NODE_REQUEST: (state) => {
    state.nodeStatus = 'loading'
    state.message = ''
  },
  NODE_REPLACED: (state, data) => {
    state.nodeStatus = 'success'
    Vue.set(state.nodes, data.mac, data)
  },
  NODE_UPDATED: (state, params) => {
    state.nodeStatus = 'success'
    Vue.set(state.nodes[params.mac], params.prop, params.data)
  },
  NODE_DESTROYED: (state, mac) => {
    state.nodeStatus = 'success'
    Vue.set(state.nodes, mac, null)
  },
  NODE_ERROR: (state, response) => {
    state.nodeStatus = 'error'
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
