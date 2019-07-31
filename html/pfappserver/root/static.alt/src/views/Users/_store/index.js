/**
* "$_users" store module
*/
import Vue from 'vue'
import api from '../_api'
import { pfConfigurationActions } from '@/globals/configuration/pfConfiguration'

const inflateActions = (data) => {
  data.actions = []
  if (data.access_duration) {
    data.actions.push({ type: pfConfigurationActions.set_access_duration.value, value: data.access_duration })
  }
  if (data.access_level) {
    data.actions.push({ type: pfConfigurationActions.set_access_level.value, value: data.access_level })
  }
  if (data.can_sponsor && parseInt(data.can_sponsor)) {
    data.actions.push({ type: pfConfigurationActions.mark_as_sponsor.value, value: data.can_sponsor })
  }
  if (data.category) {
    data.actions.push({ type: pfConfigurationActions.set_role.value, value: data.category })
  }
  if (data.unregdate !== '0000-00-00 00:00:00') {
    data.actions.push({ type: pfConfigurationActions.set_unreg_date.value, value: data.unregdate })
  }
}

const deflateActions = (data) => {
  if ('actions' in data) {
    const actions = data.actions

    data.access_duration = null
    data.access_level = null
    data.can_sponsor = null
    data.category = null
    data.unregdate = null

    actions.forEach(action => {
      switch (action.type) {
        case pfConfigurationActions.set_access_duration.value:
          data.access_duration = action.value
          break
        case pfConfigurationActions.set_access_level.value:
          data.access_level = action.value
          break
        case pfConfigurationActions.mark_as_sponsor.value:
          data.sponsor = 1
          break
        case pfConfigurationActions.set_role.value:
          data.category = action.value
          break
        case pfConfigurationActions.set_unreg_date.value:
          data.unregdate = action.value
          break
        default:
          // noop
      }
    })
  }
}

// Default values
const state = {
  users: {}, // users details
  userExists: {}, // node exists true|false
  message: '',
  userStatus: '',
  createdUsers: []
}

const getters = {
  isLoading: state => state.userStatus === 'loading'
}

const actions = {
  exists: ({ state, commit }, pid) => {
    if (pid in state.userExists) {
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
  refreshUser: ({ state, commit, dispatch }, pid) => {
    if (state.users[pid]) {
      commit('USER_DESTROYED', pid)
    }
    commit('USER_REQUEST')
    dispatch('getUser', pid).then(() => {
      commit('USER_SUCCESS')
    }).catch(err => {
      commit('USER_ERROR', err.response)
      return err
    })
  },
  getUser: ({ commit, state }, pid) => {
    if (state.users[pid]) {
      return Promise.resolve(state.users[pid])
    }
    commit('USER_REQUEST')
    return api.user(pid).then(data => {
      inflateActions(data)
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
    return api.updateUser(data).then(response => {
      commit('USER_REPLACED', data)
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  },
  createPassword: ({ commit }, data) => {
    deflateActions(data)
    commit('USER_REQUEST')
    return new Promise((resolve, reject) => {
      api.createPassword(data).then(response => {
        commit('USER_SUCCESS')
        resolve(response)
      }).catch(err => {
        commit('USER_ERROR', err.response)
        reject(err)
      })
    })
  },
  updatePassword: ({ commit }, data) => {
    deflateActions(data)
    commit('USER_REQUEST')
    return new Promise((resolve, reject) => {
      api.updatePassword(data).then(response => {
        commit('USER_SUCCESS')
        resolve(response)
      }).catch(err => {
        commit('USER_ERROR', err.response)
        reject(err)
      })
    })
  },
  previewEmail: ({ commit }, user) => {
    const data = {
      args: {
        pid: user.pid,
        password: user.password
      },
      template: 'guest_local_account_creation'
    }
    commit('USER_REQUEST')
    return api.previewEmail(data).then(response => {
      commit('USER_SUCCESS')
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  },
  sendEmail: ({ commit }, data) => {
    const body = {
      template: 'guest_local_account_creation',
      args: {
        pid: data.pid,
        password: data.password
      },
      to: data.email,
      subject: data.subject
    }
    commit('USER_REQUEST')
    return api.sendEmail(body).then(response => {
      commit('USER_SUCCESS')
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
  },
  bulkDelete: ({ commit }, data) => {
    commit('USER_REQUEST')
    return api.bulkDelete(data).then(response => {
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
  CREATED_USERS_REPLACED: (state, users) => {
    state.createdUsers = users
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
