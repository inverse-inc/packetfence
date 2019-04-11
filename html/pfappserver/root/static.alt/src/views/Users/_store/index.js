/**
* "$_users" store module
*/
import Vue from 'vue'
import api from '../_api'

const STORAGE_SAVED_SEARCH = 'users-saved-search'

// Default values
const state = {
  users: {}, // users details
  userExists: {}, // node exists true|false
  message: '',
  userStatus: '',
  savedSearches: JSON.parse(localStorage.getItem(STORAGE_SAVED_SEARCH)) || []
}

const getters = {
  isLoading: state => state.userStatus === 'loading'
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
  exists: ({ commit }, pid) => {
    if (state.userExists.hasOwnProperty(pid)) {
      if (state.userExists[pid]) {
        return Promise.resolve(true)
      }
      return Promise.reject(new Error('Unknown PID'))
    }
    let body = {
      fields: ['pid'],
      limit: 1,
      query: {
        op: 'and',
        values: [{
          field: 'pid', op: 'equals', value: pid
        }]
      }
    }
    return new Promise((resolve, reject) => {
      api.search(body).then(response => {
        if (response.items.length > 0) {
          commit('USER_EXISTS', pid)
          resolve(true)
        } else {
          commit('USER_NOT_EXISTS', pid)
          reject(new Error('Unknown PID'))
        }
      }).catch(err => {
        reject(err)
      })
    })
  },
  getUser: ({ commit, state }, pid) => {
    if (state.users[pid]) {
      return Promise.resolve(state.users[pid])
    }
    commit('USER_REQUEST')
    return api.user(pid).then(data => {
      commit('USER_REPLACED', data)
      // Fetch nodes
      api.nodes(pid).then(datas => {
        commit('USER_UPDATED', { pid, prop: 'nodes', data: datas })
      })
      // Fetch security_events
      api.securityEvents(pid).then(datas => {
        commit('USER_UPDATED', { pid, prop: 'security_events', data: datas })
      })
      return JSON.parse(JSON.stringify(state.users[pid]))
    }).catch(err => {
      commit('USER_ERROR', err.response)
      return err
    })
  },
  createUser: ({ commit }, data) => {
    commit('USER_REQUEST')
    return new Promise((resolve, reject) => {
      api.createUser(data).then(response => {
        commit('USER_REPLACED', data)
        commit('USER_EXISTS', data.pid)
        resolve(response)
      }).catch(err => {
        commit('USER_ERROR', err.response)
        reject(err)
      })
    })
  },
  updateUser: ({ commit }, data) => {
    commit('USER_REQUEST')
    delete data.access_duration
    delete data.access_level
    return api.updateUser(data).then(response => {
      commit('USER_REPLACED', data)
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  },
  unassignUserNodes: ({ commit }, pid) => {
    commit('USER_REQUEST')
    return new Promise((resolve, reject) => {
      api.unassignUserNodes(pid).then(response => {
        commit('USER_UPDATED', { pid: pid, prop: 'nodes', data: [] })
        resolve(response)
      }).catch(err => {
        commit('USER_ERROR', err.response)
        reject(err)
      })
    })
  },
  deleteUser: ({ commit }, pid) => {
    commit('USER_REQUEST')
    return new Promise((resolve, reject) => {
      api.deleteUser(pid).then(response => {
        commit('USER_DESTROYED', pid)
        commit('USER_NOT_EXISTS', pid)
        resolve(response)
      }).catch(err => {
        commit('USER_ERROR', err.response)
        reject(err)
      })
    })
  },
  bulkRegisterNodes: ({ commit }, data) => {
    commit('USER_REQUEST')
    return api.bulkRegisterNodes(data).then(response => {
      commit('USER_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  },
  bulkDeregisterNodes: ({ commit }, data) => {
    commit('USER_REQUEST')
    return api.bulkDeregisterNodes(data).then(response => {
      commit('USER_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  },
  bulkApplySecurityEvent: ({ commit }, data) => {
    commit('USER_REQUEST')
    return api.bulkCloseSecurityEvents(data).then(response => {
      commit('USER_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  },
  bulkCloseSecurityEvents: ({ commit }, data) => {
    commit('USER_REQUEST')
    return api.bulkCloseSecurityEvents(data).then(response => {
      commit('USER_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  },
  bulkApplyRole: ({ commit }, data) => {
    commit('USER_REQUEST')
    return api.bulkApplyRole(data).then(response => {
      commit('USER_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  },
  bulkApplyBypassRole: ({ commit }, data) => {
    commit('USER_REQUEST')
    return api.bulkApplyBypassRole(data).then(response => {
      commit('USER_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  },
  bulkReevaluateAccess: ({ commit }, data) => {
    commit('USER_REQUEST')
    return api.bulkReevaluateAccess(data).then(response => {
      commit('USER_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  },
  bulkRefreshFingerbank: ({ commit }, data) => {
    commit('USER_REQUEST')
    return api.bulkReevaluateAccess(data).then(response => {
      commit('USER_BULK_SUCCESS', response)
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  }
}

const mutations = {
  USER_REQUEST: (state) => {
    state.userStatus = 'loading'
  },
  USER_REPLACED: (state, data) => {
    Vue.set(state.users, data.pid, data)
    // TODO: update items if found in it
    state.userStatus = 'success'
  },
  USER_UPDATED: (state, params) => {
    state.userStatus = 'success'
    if (params.pid in state.users) {
      Vue.set(state.users[params.pid], params.prop, params.data)
    }
  },
  USER_BULK_SUCCESS: (state, response) => {
    state.nodeStatus = 'success'
    response.forEach(item => {
      if (item.pid in state.users) {
        Vue.set(state.users, item.pid, null)
      }
    })
  },
  USER_DESTROYED: (state, pid) => {
    state.userStatus = 'success'
    Vue.set(state.users, pid, null)
  },
  USER_SUCCESS: (state) => {
    state.userStatus = 'success'
  },
  USER_ERROR: (state, response) => {
    state.userStatus = 'error'
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  USER_EXISTS: (state, pid) => {
    Vue.set(state.userExists, pid, true)
  },
  USER_NOT_EXISTS: (state, pid) => {
    Vue.set(state.userExists, pid, false)
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
