/**
* "$_services" store module
*/
import Vue from 'vue'
import api from '../_api'

const types = {
  LOADING: 'loading',
  ENABLING: 'enabling',
  DISABLING: 'disabling',
  RESTARTING: 'restarting',
  STARTING: 'starting',
  STOPPING: 'stopping',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const state = {
  cache: {}, // items details
  message: '',
  requestStatus: ''
}

const getters = {
  isLoading: state => state.requestStatus === types.LOADING

}

const actions = {
  all: () => {
    return api.services().then(response => {
      return response.items
    })
  },
  getService: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id]).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('SERVICE_REQUEST')
    return api.service(id).then(response => {
      commit('SERVICE_STATUS', { id, response })
      return JSON.parse(JSON.stringify(state.cache[id]))
    }).catch((err) => {
      const { response } = err
      commit('SERVICE_ERROR', { id, response })
      throw err
    })
  },
  disableService: ({ state, commit }, id) => {
    commit('SERVICE_DISABLING', id)
    return api.disableService(id).then(response => {
      commit('SERVICE_DISABLED', { id, response })
      return state.cache[id]
    }).catch((err) => {
      const { response } = err
      commit('SERVICE_ERROR', { id, response })
      throw err
    })
  },
  enableService: ({ state, commit }, id) => {
    commit('SERVICE_ENABLING', id)
    return api.enableService(id).then(response => {
      commit('SERVICE_ENABLED', { id, response })
      return state.cache[id]
    }).catch((err) => {
      const { response } = err
      commit('SERVICE_ERROR', { id, response })
      throw err
    })
  },
  restartService: ({ state, commit }, id) => {
    commit('SERVICE_RESTARTING', id)
    return api.restartService(id).then(response => {
      commit('SERVICE_RESTARTED', { id, response })
      return state.cache[id]
    }).catch((err) => {
      const { response } = err
      commit('SERVICE_ERROR', { id, response })
      throw err
    })
  },
  startService: ({ state, commit }, id) => {
    commit('SERVICE_STARTING', id)
    return api.startService(id).then(response => {
      commit('SERVICE_STARTED', { id, response })
      return state.cache[id]
    }).catch((err) => {
      const { response } = err
      commit('SERVICE_ERROR', { id, response })
      throw err
    })
  },
  stopService: ({ state, commit }, id) => {
    commit('SERVICE_STOPPING', id)
    return api.stopService(id).then(response => {
      commit('SERVICE_STOPPED', { id })
      return state.cache[id]
    }).catch((err) => {
      const { response } = err
      commit('SERVICE_ERROR', { id, response })
      throw err
    })
  }
}

const mutations = {
  SERVICE_REQUEST: (state, id) => {
    Vue.set(state.cache, id, (state.cache[id] || {}))
    Vue.set(state.cache[id], 'status', types.LOADING)
    state.requestStatus = types.LOADING
    state.message = ''
  },
  SERVICE_STATUS: (state, data) => {
    const { id = null, response: { pid = 0, alive = 0, enabled = 0, managed = 0 } } = data
    Vue.set(state.cache, id, (state.cache[id] || {}))
    Vue.set(state.cache[id], 'pid', parseInt(pid))
    Vue.set(state.cache[id], 'alive', !!alive)
    Vue.set(state.cache[id], 'enabled', !!enabled)
    Vue.set(state.cache[id], 'managed', !!managed)
    Vue.set(state.cache[id], 'status', types.SUCCESS)
    state.requestStatus = types.SUCCESS
  },
  SERVICE_DISABLING: (state, id) => {
    Vue.set(state.cache, id, (state.cache[id] || {}))
    Vue.set(state.cache[id], 'status', types.DISABLING)
    state.requestStatus = types.LOADING
  },
  SERVICE_DISABLED: (state, data) => {
    const { id } = data
    Vue.set(state.cache[id], 'enabled', false)
    Vue.set(state.cache[id], 'status', types.SUCCESS)
    state.requestStatus = types.SUCCESS
  },
  SERVICE_ENABLING: (state, id) => {
    Vue.set(state.cache, id, (state.cache[id] || {}))
    Vue.set(state.cache[id], 'status', types.ENABLING)
    state.requestStatus = types.LOADING
  },
  SERVICE_ENABLED: (state, data) => {
    const { id } = data
    Vue.set(state.cache[id], 'enabled', true)
    Vue.set(state.cache[id], 'status', types.SUCCESS)
    state.requestStatus = types.SUCCESS
  },
  SERVICE_RESTARTING: (state, id) => {
    Vue.set(state.cache, id, (state.cache[id] || {}))
    Vue.set(state.cache[id], 'status', types.RESTARTING)
    state.requestStatus = types.LOADING
  },
  SERVICE_RESTARTED: (state, data) => {
    const { id, response } = data
    Vue.set(state.cache[id], 'pid', parseInt(response.pid))
    Vue.set(state.cache[id], 'alive', true)
    Vue.set(state.cache[id], 'status', types.SUCCESS)
    state.requestStatus = types.SUCCESS
  },
  SERVICE_STARTING: (state, id) => {
    Vue.set(state.cache, id, (state.cache[id] || {}))
    Vue.set(state.cache[id], 'status', types.STARTING)
    state.requestStatus = types.LOADING
  },
  SERVICE_STARTED: (state, data) => {
    const { id, response } = data
    Vue.set(state.cache[id], 'pid', parseInt(response.pid))
    Vue.set(state.cache[id], 'alive', true)
    Vue.set(state.cache[id], 'status', types.SUCCESS)
    state.requestStatus = types.SUCCESS
  },
  SERVICE_STOPPING: (state, id) => {
    Vue.set(state.cache, id, (state.cache[id] || {}))
    Vue.set(state.cache[id], 'status', types.STOPPING)
    state.requestStatus = types.LOADING
  },
  SERVICE_STOPPED: (state, data) => {
    const { id } = data
    Vue.set(state.cache[id], 'pid', 0)
    Vue.set(state.cache[id], 'alive', false)
    Vue.set(state.cache[id], 'status', types.SUCCESS)
    state.requestStatus = types.SUCCESS
  },
  SERVICE_ERROR: (state, data) => {
    const { id, response } = data
    Vue.set(state.cache[id], 'status', types.ERROR)
    state.requestStatus = types.ERROR
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
