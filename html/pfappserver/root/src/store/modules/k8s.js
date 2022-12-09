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
    status: ''
  }
}

const getters = {
  isLoading: state => state.status === types.LOADING,
}

const actions = {
  getServices: ({ state, commit }) => {
    commit('K8S_REQUEST')
    const aside = () => api.services().then(services => {
      commit('K8S_SERVICES_SUCCESS', services)
      return state.services
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('SERVICE_ERROR', error)
      throw err
    })
    if (state.services) {
      aside()
      return state.services
    }
    return aside()
  },
  getService: ({ state, commit }, service) => {
    commit('K8S_REQUEST')
    const aside = () => api.service(service).then(response => {
      commit('K8S_SERVICE_SUCCESS', { service, response })
      return state.services[service]
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('SERVICE_ERROR', error)
      throw err
    })
    if (state.services) {
      aside()
      return state.services[service]
    }
    return aside()

  },
  restartService: ({ commit }, service) => {
    const pollStatus = (service) => {
      return api.service(service).then(response => {
        commit('K8S_SERVICE_SUCCESS', { service, response })
        const { total_replicas, updated_replicas } = response
        if (updated_replicas !== total_replicas) {
          pollStatusDelayed(service)
        }
      })
    }
    const pollStatusDelayed = (service) => {
      return new Promise((resolve, reject) => {
        setTimeout(() => {
          pollStatus(service)
            .then(resolve)
            .catch(reject)
        }, 1000)
      })
    }
    commit('K8S_RESTARTING', service)
    return api.restart(service).then(response => {
      commit('K8S_RESTARTED', { service, response })
      return pollStatusDelayed(service)
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('SERVICE_ERROR', error)
      throw err
    })
  }
}

const mutations = {
  K8S_REQUEST: state => {
    state.status = types.LOADING
  },
  K8S_SERVICES_SUCCESS: (state, services) => {
    state.status = types.SUCCESS
    state.services = services
    state.message = ''
  },
  K8S_SERVICE_SUCCESS: (state, { service, response }) => {
    state.status = types.SUCCESS
    state.services[service] = response
    state.message = ''
  },
  K8S_ERROR: (state, error) => {
    state.status = types.ERROR
    state.message = error
  },

  K8S_RESTARTING: (state, service) => {
    state.status = types.LOADING
    state.services[service].status = types.LOADING
  },
  K8S_RESTARTED: (state, { service }) => {
    state.status = types.SUCCESS
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
