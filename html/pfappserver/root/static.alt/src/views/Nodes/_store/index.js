/**
* "$_nodes" store module
*/
import Vue from 'vue'
import api from '../_api'

const STORAGE_SAVED_SEARCH = 'nodes-saved-search'

// Default values
const state = {
  nodes: {}, // nodes details
  nodeExists: {}, // node exists true|false
  message: '',
  nodeStatus: '',
  savedSearches: JSON.parse(localStorage.getItem(STORAGE_SAVED_SEARCH)) || []
}

const getters = {
  isLoading: state => state.nodeStatus === 'loading'
}

const actions = {
  addSavedSearch: ({ commit }, search) => {
    let savedSearches = state.savedSearches
    savedSearches = state.savedSearches.filter(searches => searches.name !== search.name)
    savedSearches.push(search)
    savedSearches.sort((a, b) => {
      return a.name.localeCompare(b.name)
    })
    commit('SAVED_SEARCHES_UPDATED', savedSearches)
    localStorage.setItem(STORAGE_SAVED_SEARCH, JSON.stringify(savedSearches))
  },
  deleteSavedSearch: ({ commit }, search) => {
    let savedSearches = state.savedSearches.filter(searches => searches.name !== search.name)
    commit('SAVED_SEARCHES_UPDATED', savedSearches)
    localStorage.setItem(STORAGE_SAVED_SEARCH, JSON.stringify(savedSearches))
  },
  exists: ({ commit }, mac) => {
    if (state.nodeExists.hasOwnProperty(mac)) {
      if (state.nodeExists[mac]) {
        return Promise.resolve(true)
      }
      return Promise.reject(new Error('Unknown MAC'))
    }
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
      api.search(body).then(response => {
        if (response.items.length > 0) {
          commit('NODE_EXISTS', mac)
          resolve(true)
        } else {
          commit('NODE_NOT_EXISTS', mac)
          reject(new Error('Unknown MAC'))
        }
      }).catch(err => {
        reject(err)
      })
    })
  },
  getNode: ({ state, commit }, mac) => {
    let node = { fingerbank: {} } // ip4: { history: [] }, ip6: { history: [] } }

    if (state.nodes[mac]) {
      return Promise.resolve(state.nodes[mac])
    }

    commit('NODE_REQUEST')
    return api.node(mac).then(item => {
      Object.assign(node, item)
      if (node.status === null) {
        node.status = 'unreg'
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

      // Fetch security_events
      api.security_events(mac).then(items => {
        commit('NODE_UPDATED', { mac, prop: 'security_events', data: items })
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

      // Fetch dhcpoption82
      api.dhcpoption82(mac).then(items => {
        commit('NODE_UPDATED', { mac, prop: 'dhcpoption82', data: items })
      })

      return node
    })
  },
  createNode: ({ commit }, data) => {
    commit('NODE_REQUEST')
    if (data.unreg_date && data.unreg_time) {
      data.unregdate = `${data.unreg_date} ${data.unreg_time}`
    }
    return new Promise((resolve, reject) => {
      api.createNode(data).then(response => {
        commit('NODE_REPLACED', data)
        commit('NODE_EXISTS', data.mac)
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  updateNode: ({ commit }, data) => {
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
  deleteNode: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return new Promise((resolve, reject) => {
      api.deleteNode(data).then(response => {
        commit('NODE_DESTROYED', data)
        commit('NODE_NOT_EXISTS', data.mac)
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  registerNode: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return new Promise((resolve, reject) => {
      api.registerNode(data).then(response => {
        commit('NODE_REPLACED', data)
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  registerBulkNodes: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.registerBulkNodes(data).then(response => {
        response.items.filter(item => item.status === 'success').forEach(function (item, index, items) {
          commit('NODE_UPDATED', { mac: item.mac, prop: 'status', data: 'reg' })
          commit('$_nodes_searchable/ITEM_UPDATED', { mac: item.mac, prop: 'status', data: 'reg' }, { root: true })
        })
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  deregisterNode: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return new Promise((resolve, reject) => {
      api.deregisterNode(data).then(response => {
        commit('NODE_REPLACED', data)
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  deregisterBulkNodes: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.deregisterBulkNodes(data).then(response => {
        response.items.filter(item => item.status === 'success').forEach(function (item, index, items) {
          commit('NODE_UPDATED', { mac: item.mac, prop: 'status', data: 'unreg' })
          commit('$_nodes_searchable/ITEM_UPDATED', { mac: item.mac, prop: 'status', data: 'unreg' }, { root: true })
        })
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  clearSecurityEventNode: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return new Promise((resolve, reject) => {
      api.clearSecurityEventNode(data).then(response => {
        commit('NODE_REPLACED', data)
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  applySecurityEventBulkNodes: ({ commit }, data) => {
    return new Promise((resolve, reject) => {
      api.applySecurityEventBulkNodes(data).then(response => {
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  clearSecurityEventBulkNodes: ({ commit }, data) => {
    return new Promise((resolve, reject) => {
      api.clearSecurityEventBulkNodes(data).then(response => {
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  reevaluateAccessBulkNodes: ({ commit }, data) => {
    return new Promise((resolve, reject) => {
      api.reevaluateAccessBulkNodes(data).then(response => {
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  restartSwitchportBulkNodes: ({ commit }, data) => {
    return new Promise((resolve, reject) => {
      api.restartSwitchportBulkNodes(data).then(response => {
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  refreshFingerbankBulkNodes: ({ commit }, data) => {
    return new Promise((resolve, reject) => {
      api.refreshFingerbankBulkNodes(data).then(response => {
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  roleNode: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.updateNode(data).then(response => {
        if (response.status === 'success') {
          commit('NODE_UPDATED', { mac: data.mac, prop: 'category_id', data: data.category_id })
          commit('$_nodes_searchable/ITEM_UPDATED', { mac: data.mac, prop: 'category_id', data: data.category_id }, { root: true })
        }
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  roleBulkNodes: ({ commit }, data) => {
    return new Promise((resolve, reject) => {
      api.roleBulkNodes(data).then(response => {
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  bypassRoleNode: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.updateNode(data).then(response => {
        if (response.status === 'success') {
          commit('NODE_UPDATED', { mac: data.mac, prop: 'bypass_role_id', data: data.bypass_role_id })
          commit('$_nodes_searchable/ITEM_UPDATED', { mac: data.mac, prop: 'bypass_role_id', data: data.bypass_role_id }, { root: true })
        }
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  bypassRoleBulkNodes: ({ commit }, data) => {
    return new Promise((resolve, reject) => {
      api.bypassRoleBulkNodes(data).then(response => {
        resolve(response)
      }).catch(err => {
        commit('NODE_ERROR', err.response)
        reject(err)
      })
    })
  },
  reevaluateAccessNode: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.reevaluateAccessNode(data).then(response => {
        if (response.status === 'success') {
          // noop
        }
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  refreshFingerbankNode: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.refreshFingerbankNode(data).then(response => {
        if (response.status === 'success') {
          // noop
        }
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  restartSwitchportNode: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.restartSwitchportNode(data).then(response => {
        if (response.status === 'success') {
          // noop
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
    if (params.mac in state.nodes) {
      Vue.set(state.nodes[params.mac], params.prop, params.data)
    }
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
  NODE_EXISTS: (state, mac) => {
    Vue.set(state.nodeExists, mac, true)
  },
  NODE_NOT_EXISTS: (state, mac) => {
    Vue.set(state.nodeExists, mac, false)
  },
  SAVED_SEARCHES_UPDATED: (state, searches) => {
    state.savedSearches = searches
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
