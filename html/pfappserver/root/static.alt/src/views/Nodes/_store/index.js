/**
* "$_nodes" store module
*/
import Vue from 'vue'
import api from '../_api'

const STORAGE_SEARCH_LIMIT_KEY = 'nodes-search-limit'
const STORAGE_VISIBLE_COLUMNS_KEY = 'nodes-visible-columns'

// Default values
const state = {
  items: [], // search results
  nodes: {}, // nodes details
  message: '',
  nodeStatus: '',
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
  isLoading: state => state.nodeStatus === 'loading',
  isLoadingResults: state => state.searchStatus === 'loading'
}

const actions = {
  setSearchFields: ({commit}, fields) => {
    commit('SEARCH_FIELDS_UPDATED', fields)
  },
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
  setVisibleColumns: ({commit}, columns) => {
    localStorage.setItem(STORAGE_VISIBLE_COLUMNS_KEY, JSON.stringify(columns))
    commit('VISIBLE_COLUMNS_UPDATED', columns)
  },
  search: ({state, getters, commit, dispatch}, page) => {
    let sort = [state.searchSortDesc ? `${state.searchSortBy} DESC` : state.searchSortBy]
    let body = {
      cursor: state.searchPageSize * (page - 1),
      limit: state.searchPageSize,
      fields: state.searchFields,
      sort
    }
    let apiPromise = state.searchQuery ? api.search(Object.assign(body, {query: state.searchQuery})) : api.all(body)
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
  exists: ({commit}, mac) => {
    let body = {
      fields: ['mac'],
      limit: 1,
      query: {
        op: 'and',
        values: [{
          field: 'mac', op: 'equals', value: mac
        }]
      }
    }
    return new Promise((resolve, reject) => {
      commit('SEARCH_REQUEST')
      api.search(body).then(response => {
        commit('SEARCH_SUCCESS')
        if (response.items.length > 0) {
          resolve(true)
        } else {
          reject(new Error('Unknown MAC'))
        }
      }).catch(err => {
        commit('SEARCH_ERROR', err.response)
        reject(err)
      })
    })
  },
  getNode: ({state, commit}, mac) => {
    let node = { fingerbank: {} } // ip4: { history: [] }, ip6: { history: [] } }

    if (state.nodes[mac]) {
      return Promise.resolve(state.nodes[mac])
    }

    commit('NODE_REQUEST')
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

      // Fetch fingerbank
      let fingerbank = {}
      api.fingerbankInfo(mac).then(item => {
        Object.assign(fingerbank, item)
      }).catch(() => {
        // noop
      }).finally(() => {
        commit('NODE_UPDATED', { mac, prop: 'fingerbank', data: fingerbank })
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
  },
  registerNode: ({commit}, mac) => {
    commit('NODE_REQUEST')
    return new Promise((resolve, reject) => {
      api.registerNode(mac).then(response => {
        commit('NODE_REPLACED', mac)
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  registerBulkNodes: ({commit}, macs) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.registerBulkNodes(macs).then(response => {
        response.items.filter(item => item.status === 'success').forEach(function (item, index, items) {
          commit('ITEM_UPDATED', { mac: item.mac, prop: 'status', data: 'reg' })
        })
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  deregisterNode: ({commit}, mac) => {
    commit('NODE_REQUEST')
    return new Promise((resolve, reject) => {
      api.deregisterNode(mac).then(response => {
        commit('NODE_REPLACED', mac)
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  deregisterBulkNodes: ({commit}, macs) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.deregisterBulkNodes(macs).then(response => {
        response.items.filter(item => item.status === 'success').forEach(function (item, index, items) {
          commit('ITEM_UPDATED', { mac: item.mac, prop: 'status', data: 'unreg' })
        })
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  clearViolationNode: ({commit}, mac) => {
    commit('NODE_REQUEST')
    return new Promise((resolve, reject) => {
      api.clearViolationNode(mac).then(response => {
        commit('NODE_REPLACED', mac)
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  clearViolationBulkNodes: ({commit}, macs) => {
    return new Promise((resolve, reject) => {
      api.clearViolationBulkNodes(macs).then(response => {
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  reevaluateAccessBulkNodes: ({commit}, macs) => {
    return new Promise((resolve, reject) => {
      api.reevaluateAccessBulkNodes(macs).then(response => {
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  restartSwitchportBulkNodes: ({commit}, macs) => {
    return new Promise((resolve, reject) => {
      api.restartSwitchportBulkNodes(macs).then(response => {
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  roleNode: ({commit}, data) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.updateNode(data).then(response => {
        if (response.status === 'success') {
          commit('ITEM_UPDATED', { mac: data.mac, prop: 'category_id', data: data.category_id })
        }
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  bypassRoleNode: ({commit}, data) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.updateNode(data).then(response => {
        if (response.status === 'success') {
          commit('ITEM_UPDATED', { mac: data.mac, prop: 'bypass_role_id', data: data.bypass_role_id })
        }
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
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
      state.items = response.items
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
  },
  ITEM_VARIANT: (state, params) => {
    let index = state.items.findIndex(item => item.mac === params.mac)
    let variant = params.variant || ''
    switch (params.status) {
      case 'success':
        variant = 'success'
        break
      case 'skipped':
        variant = 'warning'
        break
      case 'failed':
        variant = 'danger'
        break
    }
    Vue.set(state.items[index], '_rowVariant', variant)
  },
  ITEM_MESSAGE: (state, params) => {
    let index = state.items.findIndex(item => item.mac === params.mac)
    Vue.set(state.items[index], '_message', params.message)
  },
  ITEM_UPDATED: (state, params) => {
    let index = state.items.findIndex(item => item.mac === params.mac)
    Vue.set(state.items[index], params.prop, params.data)
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
