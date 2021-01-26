/**
* "system" store module
*/
import Vue from 'vue'
import i18n from '@/utils/locale'
import store from '@/store'
import apiCall from '@/utils/api'
import acl from '@/utils/acl'

const api = {
  getSummary: () => {
    return apiCall.getQuiet('system_summary').then(response => {
      return response.data
    })
  },
  getDnsServers: () => {
    return apiCall.getQuiet('config/system/dns_servers').then(response => {
      return response.data
    })
  },
  getGateway: () => {
    return apiCall.getQuiet('config/system/gateway').then(response => {
      return response.data
    })
  },
  getHostname: () => {
    return apiCall.getQuiet('config/system/hostname').then(response => {
      return response.data
    })
  },
  setDnsServers: (data) => {
    const put = data.quiet ? 'putQuiet' : 'put'
    return apiCall[put]('config/system/dns_servers', { dns_servers: data.dns_servers }).then(response => {
      return response.data
    })
  },
  setGateway: (data) => {
    const put = data.quiet ? 'putQuiet' : 'put'
    return apiCall[put]('config/system/gateway', { gateway: data.gateway }).then(response => {
      return response.data
    })
  },
  setHostname: (data) => {
    const put = data.quiet ? 'putQuiet' : 'put'
    return apiCall[put]('config/system/hostname', { hostname: data.hostname }).then(response => {
      return response.data
    })
  }
}

const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const initialState = () => {
  return {
    summary: false,
    dns_servers: [],
    gateway: '',
    hostname: '',
    message: '',
    requestStatus: ''
  }
}

const getters = {
  hostname: state => state.summary ? state.summary.hostname : state.hostname,
  isInline: state => state.summary.is_inline_configured,
  isLoading: state => state.requestStatus === types.LOADING,
  readonlyMode: state => state.summary.readonly_mode,
  version: state => state.summary.version,
  gateway: state => state.gateway
}

const actions = {
  getSummary: ({ commit, state }) => {
    if (state.summary) {
      return Promise.resolve(state.summary)
    }
    if (acl.$can('read', 'system')) {
      commit('SYSTEM_REQUEST')
      return new Promise((resolve, reject) => {
        api.getSummary().then(data => {
          commit('SYSTEM_SUCCESS', data)
          if (data.readonly_mode) {
            store.dispatch('notification/danger', {
              message: i18n.t('The database is in readonly mode. Not all functionality is available.')
            })
          }
          resolve(state.summary)
        }).catch(err => {
          commit('SYSTEM_ERROR', err.response)
          reject(err)
        })
      })
    } else {
      commit('SYSTEM_SUCCESS', {})
      return state.summary
    }
  },
  getDnsServers: ({ commit, state }) => {
    if (state.dns_servers.length) {
      return Promise.resolve(state.dns_servers)
    }
    commit('SYSTEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.getDnsServers().then(data => {
        const { dns_servers = [] } = data
        commit('SYSTEM_ITEM_SUCCESS', { dns_servers })
        resolve(state.dns_servers)
      }).catch(err => {
        commit('SYSTEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  getGateway: ({ commit, state }) => {
    if (state.gateway) {
      return Promise.resolve(state.gateway)
    }
    commit('SYSTEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.getGateway().then(data => {
        commit('SYSTEM_ITEM_SUCCESS', { gateway: data.item })
        resolve(state.gateway)
      }).catch(err => {
        commit('SYSTEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  getHostname: ({ commit, state }, options = {}) => {
    const { cache = true } = options
    if (cache && state.hostname) {
      return Promise.resolve(state.hostname)
    }
    commit('SYSTEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.getHostname().then(data => {
        commit('SYSTEM_ITEM_SUCCESS', { hostname: data.item })
        resolve(state.hostname)
      }).catch(err => {
        commit('SYSTEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  setGateway: ({ commit, state }, data) => {
    commit('SYSTEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.setGateway(data).then(() => {
        commit('SYSTEM_ITEM_SUCCESS', { gateway: data.gateway })
        resolve(state.gateway)
      }).catch(err => {
        commit('SYSTEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  setHostname: ({ commit, state }, data) => {
    commit('SYSTEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.setHostname(data).then(() => {
        commit('SYSTEM_ITEM_SUCCESS', { hostname: data.hostname })
        resolve(state.hostname)
      }).catch(err => {
        commit('SYSTEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  setDnsServers: ({ commit, state }, data) => {
    commit('SYSTEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.setDnsServers(data).then(() => {
        commit('SYSTEM_ITEM_SUCCESS', { dns_servers: data.dns_servers })
        resolve(state.dns_servers)
      }).catch(err => {
        commit('SYSTEM_ERROR', err.response)
        reject(err)
      })
    })
  }
}

const mutations = {
  SYSTEM_REQUEST: (state) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  SYSTEM_SUCCESS: (state, data) => {
    Vue.set(state, 'summary', data)
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  SYSTEM_ITEM_SUCCESS: (state, data) => {
    Object.keys(data).forEach(key => {
      Vue.set(state, key, data[key])
    })
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  SYSTEM_ERROR: (state, data = {}) => {
    state.requestStatus = types.ERROR
    const { response: { data: { message } = {} } = {} } = data
    if (message) {
      state.message = message
    }
  },
  // eslint-disable-next-line no-unused-vars
  $RESET: (state) => {
    state = initialState()
  }
}

export default {
  namespaced: true,
  state: initialState(),
  getters,
  actions,
  mutations
}
