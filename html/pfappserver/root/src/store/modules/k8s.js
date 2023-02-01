/**
* "k8s" store module
*/
import apiCall from '@/utils/api'

const api = {
  services: () => {
    return apiCall.getQuiet('k8s-services/status_all').then(response => {
      return response.data.items
    })
  },
  service: service => {
    return apiCall.getQuiet(['k8s-service', service, 'status']).then(response => {
      return response.data
    })
  },
  restart: service => {
    return apiCall.postQuiet(['k8s-service', service, 'restart']).then(response => {
      return response.data
    })
  },
}

const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const initialState = () => {
  return {
    services: false,
    message: '',
    status: '',
    ts: 0
  }
}

const delay = 3E3 // 1s
const grace = 5E3 // 3s

const getters = {
  isLoading: state => state.status === types.LOADING,
  services: state => state.services,
}

const actions = {
  getServices: ({ state, commit, dispatch }) => {
    commit('K8S_REQUEST')
    const aside = () => api.services().then(services => {
      commit('K8S_SERVICES_SUCCESS', services)
      return state.services
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('K8S_SERVICES_ERROR', error)
      throw err
    }).finally(() => dispatch('pollServices'))
    if (state.services) {
      aside()
      return state.services
    }
    return aside()
  },
  getService: ({ state, commit, dispatch }, service) => {
    commit('K8S_REQUEST')
    const aside = () => api.service(service).then(response => {
      commit('K8S_SERVICE_SUCCESS', { service, response })
      return state.services[service]
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('K8S_SERVICE_ERROR', { service, error })
      throw err
    }).finally(() => dispatch('pollServices'))
    if (state.services) {
      aside()
      return state.services[service]
    }
    return aside()

  },
  restartService: ({ commit, dispatch }, service) => {
    commit('K8S_RESTARTING', service)
    return api.restart(service).then(response => {
      commit('K8S_RESTARTED', { service, response })
      return dispatch('pollServices')
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('K8S_SERVICE_ERROR', { service, error })
      throw err
    })
  },
  pollServices: ({ commit, state }) => {
    const pollServices = () => {
      return api.services().then(services => {
        commit('K8S_SERVICES_SUCCESS', services)
        const ts = Date.now()
        if (ts < state.ts + grace) {
          // grace period
          return setTimeout(pollServices, delay)
        }
        if (Object.values(services).filter(service => service.total_replicas !== service.updated_replicas || !service.available).length > 0) {
          // waiting
          return setTimeout(pollServices, delay)
        }
        // done
        commit('K8S_POLL_STOP')
      })
    }
    if (!state.ts) { // singleton
      commit('K8S_POLL_START')
      pollServices()
    }
    else { // bump ts
      commit('K8S_POLL_START')
    }
  }
}

const mutations = {
  K8S_REQUEST: state => {
    state.status = types.LOADING
  },
  K8S_SERVICES_SUCCESS: (state, services) => {
    state.status = types.SUCCESS
    // avoid squashing w/ merge
    state.services = Object.entries(services).reduce((merged, [id, service]) => {
      merged[id] = { ...state.services[id], id, ...service }
      return merged
    }, {})
    state.message = ''
  },
  K8S_SERVICES_ERROR: (state, error) => {
    state.status = types.ERROR
    state.message = error
  },
  K8S_SERVICE_SUCCESS: (state, { service, response }) => {
    state.status = types.SUCCESS
    if (!state.services) {
      state.services = {}
    }
    // avoid squashing w/ merge
    state.services[service] = { ...state.services[service], ...response }
    state.message = ''
  },
  K8S_SERVICE_ERROR: (state, { error }) => {
    state.status = types.ERROR
    state.message = error
  },
  K8S_POLL_START: (state) => {
    state.ts = Date.now()
  },
  K8S_POLL_STOP: (state) => {
    state.ts = 0
  },

  K8S_RESTARTING: (state, service) => {
    state.status = types.LOADING
    if (!state.services) {
      state.services = {}
    }
    state.services[service].status = types.LOADING
  },
  K8S_RESTARTED: (state, { service }) => {
    state.status = types.SUCCESS
    if (!state.services) {
      state.services = {}
    }
    state.services[service].status = types.SUCCESS
  },
}

export default {
  namespaced: true,
  state: initialState(),
  getters,
  actions,
  mutations
}
