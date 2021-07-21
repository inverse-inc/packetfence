/**
* "services" store module
*/
import Vue from 'vue'
import store from '@/store'
import apiCall from '@/utils/api'

const api = {
  services: () => {
    return apiCall.get('services').then(response => {
      return response.data.items
    })
  },
  service: name => {
    return apiCall.get(`service/${name}/status`).then(response => {
      return response.data
    })
  },
  disableService: name => {
    return apiCall.post(`service/${name}/disable`).then(response => {
      const { data: { disable } } = response
      if (parseInt(disable) > 0) {
        return response.data
      } else {
        throw new Error(`Could not disable ${name}`)
      }
    })
  },
  enableService: name => {
    return apiCall.post(`service/${name}/enable`).then(response => {
      const { data: { enable } } = response
      if (parseInt(enable) > 0) {
        return response.data
      } else {
        throw new Error(`Could not enable ${name}`)
      }
    })
  },
  restartService: body => {
    const post = body.quiet ? 'postQuiet' : 'post'
    return apiCall[post](`service/${body.id}/restart`).then(response => {
      const { data: { restart } } = response
      if (parseInt(restart) > 0) {
        return response.data
      } else {
        throw new Error(`Could not restart ${body.id}`)
      }
    })
  },
  restartServiceAsync: id => {
    return apiCall.postQuiet(`service/${id}/restart`, { async: true })
  },
  startService: name => {
    return apiCall.post(`service/${name}/start`).then(response => {
      const { data: { start } } = response
      if (parseInt(start) > 0) {
        return response.data
      } else {
        throw new Error(`Could not start ${name}`)
      }
    })
  },
  startServiceAsync: id => {
    return apiCall.postQuiet(`service/${id}/start`, { async: true })
  },
  stopService: name => {
    return apiCall.post(`service/${name}/stop`).then(response => {
      const { data: { stop } } = response
      if (parseInt(stop) > 0) {
        return response.data
      } else {
        throw new Error(`Could not stop ${name}`)
      }
    })
  },
  updateSystemd: name => {
    return apiCall.post(['service', name, 'update_systemd'])
  },
  updateSystemdAsync: name => {
    return apiCall.post(['service', name, 'update_systemd'], { async: true })
  },
  restartSystemService: ({ id, quiet }) => {
    const post = quiet ? 'postQuiet' : 'post'
    return apiCall[post](['system_service', id, 'restart'])
  },
  startSystemService: ({ id, quiet }) => {
    const post = quiet ? 'postQuiet' : 'post'
    return apiCall[post](['system_service', id, 'start'])
  },
  stopSystemService: ({ id, quiet }) => {
    const post = quiet ? 'postQuiet' : 'post'
    return apiCall[post](['system_service', id, 'top'])
  }
}

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

export const blacklistedServices = [ // prevent start|stop|restart control on these services
  'api-frontend',
  'pf',
  'pfperl-api',
  'haproxy-admin',
  'httpd.admin_dispatcher'
]

// Default values
const initialState = () => {
  return {
    cache: {}, // items details
    message: '',
    requestStatus: ''
  }
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
  restartService: ({ state, commit }, arg) => {
    const body = (typeof arg === 'object') ? arg : { id: arg }
    const { id } = body
    commit('SERVICE_RESTARTING', id)
    return api.restartService(body).then(response => {
      commit('SERVICE_RESTARTED', { id, response })
      return state.cache[id]
    }).catch((err) => {
      const { response } = err
      commit('SERVICE_ERROR', { id, response })
      throw err
    })
  },
  restartServiceAsync: ({ state, commit }, id) => {
    commit('SERVICE_RESTARTING', id)
    return api.restartServiceAsync(id).then(response => {
      const { data: { task_id } = {} } = response
      return store.dispatch('pfqueue/pollTaskStatus', task_id).then(response => {
        commit('SERVICE_RESTARTED', { id, response })
        return state.cache[id]
      })
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
  startServiceAsync: ({ state, commit }, id) => {
    commit('SERVICE_STARTING', id)
    return api.startServiceAsync(id).then(response => {
      const { data: { task_id } = {} } = response
      return store.dispatch('pfqueue/pollTaskStatus', task_id).then(response => {
        commit('SERVICE_STARTED', { id, response })
        return state.cache[id]
      })
    })
  },
  stopService: ({ state, commit }, id) => {
    commit('SERVICE_STOPPING', id)
    return api.stopService(id).then(() => {
      commit('SERVICE_STOPPED', { id })
      return state.cache[id]
    }).catch((err) => {
      const { response } = err
      commit('SERVICE_ERROR', { id, response })
      throw err
    })
  },
  updateSystemd: (context, id) => {
    return api.updateSystemd(id)
  },
  updateSystemdAsync: (context, id) => {
    return api.updateSystemdAsync(id)
  },
  restartSystemService: ({ state, commit }, arg) => {
    const body = (typeof arg === 'object') ? arg : { id: arg }
    const { id } = body
    commit('SERVICE_RESTARTING', id)
    return api.restartSystemService(body).then(response => {
      commit('SERVICE_RESTARTED', { id, response })
      return state.cache[id]
    }).catch((err) => {
      const { response } = err
      commit('SERVICE_ERROR', { id, response })
      throw err
    })
  },
  startSystemService: ({ state, commit }, arg) => {
    const body = (typeof arg === 'object') ? arg : { id: arg }
    const { id } = body
    commit('SERVICE_STARTING', id)
    return api.startSystemService(body).then(response => {
      commit('SERVICE_STARTED', { id, response })
      return state.cache[id]
    }).catch((err) => {
      const { response } = err
      commit('SERVICE_ERROR', { id, response })
      throw err
    })
  },
  stopSystemService: ({ state, commit }, arg) => {
    const body = (typeof arg === 'object') ? arg : { id: arg }
    const { id } = body
    commit('SERVICE_STOPPING', id)
    return api.stopSystemService(body).then(() => {
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
