/**
* "$_nodes" store module
*/
import Vue from 'vue'
import api from '../_api'

// Default values
const state = {
  nodes: {}, // nodes details
  nodeExists: {}, // node exists true|false
  message: '',
  nodeStatus: ''
}

const getters = {
  isLoading: state => state.nodeStatus === 'loading'
}

const actions = {
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
    if (state.nodes[mac]) {
      return Promise.resolve(state.nodes[mac])
    }

    let node = {}

    commit('NODE_REQUEST')
    return api.node(mac).then(data => {
      Object.assign(node, data)
      if (node.status === null) {
        node.status = 'unreg'
      }
      commit('NODE_REPLACED', node)

      // Fetch ip4log history
      let ip4 = {}
      api.ip4logOpen(mac).then(data => {
        Object.assign(ip4, data)
        ip4.active = data.end_time === '0000-00-00 00:00:00'
      }).catch(() => {
        Object.assign(ip4, { active: false })
      }).finally(() => {
        api.ip4logHistory(mac).then(datas => {
          if (datas && datas.length > 0) {
            Object.assign(ip4, { history: datas })
            if (!ip4.active && !ip4.end_time) {
              ip4.end_time = datas[0].end_time
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
      api.ip6logOpen(mac).then(data => {
        Object.assign(ip6, data)
        ip6.active = data.end_time === '0000-00-00 00:00:00'
      }).catch(() => {
        Object.assign(ip6, { active: false })
      }).finally(() => {
        api.ip6logHistory(mac).then(datas => {
          if (datas && datas.length > 0) {
            Object.assign(ip6, { history: datas })
            if (!ip6.active && !ip6.end_time) {
              ip6.end_time = datas[0].end_time
            }
          }
        }).catch(() => {
          // noop
        }).finally(() => {
          commit('NODE_UPDATED', { mac, prop: 'ip6', data: ip6 })
        })
      })

      // Fetch locationlogs
      api.locationlogs(mac).then(datas => {
        commit('NODE_UPDATED', { mac, prop: 'locations', data: datas })
      })

      // Fetch security_events
      api.security_events(mac).then(datas => {
        commit('NODE_UPDATED', { mac, prop: 'security_events', data: datas })
      })

      // Fetch fingerbank
      let fingerbank = {}
      api.fingerbankInfo(mac).then(data => {
        Object.assign(fingerbank, data)
      }).catch(() => {
        // noop
      }).finally(() => {
        commit('NODE_UPDATED', { mac, prop: 'fingerbank', data: fingerbank })
      })

      // Fetch dhcpoption82
      api.dhcpoption82(mac).then(items => {
        commit('NODE_UPDATED', { mac, prop: 'dhcpoption82', data: items })
      })

      // Fetch Rapid7
      api.rapid7Info(mac).then(items => {
        commit('NODE_UPDATED', { mac, prop: 'rapid7', data: items })
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
  },
  bulkRegisterNodes: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return api.bulkRegisterNodes(data).then(response => {
      commit('NODE_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('NODE_ERROR', err.response)
    })
  },
  bulkDeregisterNodes: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return api.bulkDeregisterNodes(data).then(response => {
      commit('NODE_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('NODE_ERROR', err.response)
    })
  },
  bulkApplySecurityEvent: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return api.bulkCloseSecurityEvents(data).then(response => {
      commit('NODE_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('NODE_ERROR', err.response)
    })
  },
  bulkCloseSecurityEvents: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return api.bulkCloseSecurityEvents(data).then(response => {
      commit('NODE_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('NODE_ERROR', err.response)
    })
  },
  bulkApplyRole: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return api.bulkApplyRole(data).then(response => {
      commit('NODE_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('NODE_ERROR', err.response)
    })
  },
  bulkApplyBypassRole: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return api.bulkApplyBypassRole(data).then(response => {
      commit('NODE_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('NODE_ERROR', err.response)
    })
  },
  bulkReevaluateAccess: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return api.bulkReevaluateAccess(data).then(response => {
      commit('NODE_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('NODE_ERROR', err.response)
    })
  },
  bulkRefreshFingerbank: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return api.bulkRefreshFingerbank(data).then(response => {
      commit('NODE_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('NODE_ERROR', err.response)
    })
  },
  bulkRestartSwitchport: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return api.bulkRestartSwitchport(data).then(response => {
      commit('NODE_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('NODE_ERROR', err.response)
    })
  },
  bulkApplyBypassVlan: ({ commit }, data) => {
    commit('NODE_REQUEST')
    return api.bulkApplyBypassVlan(data).then(response => {
      commit('NODE_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('NODE_ERROR', err.response)
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
    if (!('fingerbank' in data)) data.fingerbank = {}
    Vue.set(state.nodes, data.mac, data)
    // TODO: update items if found in it
  },
  NODE_UPDATED: (state, params) => {
    state.nodeStatus = 'success'
    if (params.mac in state.nodes) {
      Vue.set(state.nodes[params.mac], params.prop, params.data)
    }
  },
  NODE_BULK_SUCCESS: (state, response) => {
    state.nodeStatus = 'success'
    response.forEach(item => {
      if (item.status === 'success' && item.mac in state.nodes) {
        Vue.set(state.nodes, item.mac, null)
      }
    })
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
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
