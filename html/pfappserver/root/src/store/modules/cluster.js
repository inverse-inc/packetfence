/**
* "cluster" store module
*/
import Vue from 'vue'
import store from '@/store'
import apiCall from '@/utils/api'

const api = (state, server) => {
  let headers = { "X-foo": 'bar' }
  if (server && state.config) { // is cluster
    const { servers: { [server]: { management_ip } = {} } = {} } = state
    if (management_ip) {
      headers['X-PacketFence-Server'] = management_ip
    }
  }

  return {
    config: () => {
      return apiCall.get('cluster/config').then(response => {
        const { data: { item, item: { CLUSTER = {} } = {} } = {} } = response
        if (Object.keys(CLUSTER).length) {
          // is cluster
          return item
        }
        // no cluster
        return apiCall.getQuiet('config/system/hostname').then(response => {
          const host = response.data.item
          return apiCall.getQuiet('config/interfaces').then(response => {
            return {
              "CLUSTER": false,
              [host]: response.data.items.reduce((server, iface) => {
                const { id, ipaddress: ip, netmask: mask, type } = iface
                if (type === "management") {
                  server.management_ip = ip
                }
                return { ...server, [`interface ${id}`]: { ip, mask } }
              }, { host })
            }
          })
        })
      })
    },
    services: () => {
      if (state.config) { // is cluster
        return apiCall.get(`services/cluster_status/${server}`).then(response => {
          return response.data.item.services
        })
      }
      else { // no cluster
        return apiCall.get('services/status_all').then(response => {
          return response.data.items
        })
      }
    },
    service: id => {
      return apiCall.get(['service', id, 'status'], {}, { headers }).then(response => {
        return response.data
      })
    },
    disable: id => {
      return apiCall.postQuiet(['service', id, 'disable'], { headers }).then(response => {
        return response.data
      })
    },
    enable: id => {
      return apiCall.postQuiet(['service', id, 'enable'], { headers }).then(response => {
        return response.data
      })
    },
    restart: id => {
      return apiCall.postQuiet(['service', id, 'restart'], { async: true }, { headers })
        .then(response => {
          const { data: { task_id } = {} } = response
          return store.dispatch('pfqueue/pollTaskStatus', { task_id, headers })
        })
    },
    start: id => {
      return apiCall.postQuiet(['service', id, 'start'], { async: true }, { headers })
        .then(response => {
          const { data: { task_id } = {} } = response
          return store.dispatch('pfqueue/pollTaskStatus', { task_id, headers })
        })
    },
    stop: id => {
      return apiCall.postQuiet(['service', id, 'stop'], { async: true }, { headers })
        .then(response => {
          const { data: { task_id } = {} } = response
          return store.dispatch('pfqueue/pollTaskStatus', { task_id, headers })
        })
    },
    restartSystem: id => {
      return apiCall.postQuiet(['system_service', id, 'restart'], { async: true }, { headers })
        .then(response => {
          const { data: { task_id } = {} } = response
          return store.dispatch('pfqueue/pollTaskStatus', { task_id, headers })
        })
    },
    startSystem: id => {
      return apiCall.postQuiet(['system_service', id, 'start'], { async: true }, { headers })
        .then(response => {
          const { data: { task_id } = {} } = response
          return store.dispatch('pfqueue/pollTaskStatus', { task_id, headers })
        })
    },
    stopSystem: id => {
      return apiCall.postQuiet(['system_service', id, 'stop'], { async: true }, { headers })
        .then(response => {
          const { data: { task_id } = {} } = response
          return store.dispatch('pfqueue/pollTaskStatus', { task_id, headers })
        })
    },
    updateSystemd: id => {
      return apiCall.postQuiet(['service', id, 'update_systemd'], { async: true }, { headers })
        .then(response => {
          const { data: { task_id } = {} } = response
          return store.dispatch('pfqueue/pollTaskStatus', { task_id, headers })
        })
    }
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

// Default values
const initialState = () => {
  return {
    config: {},
    servers: {},
    message: '',
    status: ''
  }
}

const getters = {
  isLoading: state => state.status === types.LOADING
}

const actions = {
  getConfig: ({ state, commit, dispatch }) => {
    commit('CONFIG_REQUEST')
    return api(state).config().then(item => {
      commit('CONFIG_SUCCESS', item)
      const { CLUSTER, ...servers } = item
      let promises = []
      Object.keys(servers).map(server => {
        promises.push(dispatch('getServices', server))
      })
      return Promise.all(promises).then(() => state.config)
    }).catch(err => {
      const { response } = err
      commit('CONFIG_ERROR', response)
      throw err
    })
  },
  getServices: ({ state, commit }, server) => {
    commit('SERVICES_REQUEST', server)
    return api(state, server).services().then(services => {
      commit('SERVICES_SUCCESS', { server, services })
      return state.servers[server].services
    }).catch(err => {
      const { response } = err
      commit('SERVICES_ERROR', response)
      throw err
    })
  },
  getService: ({ state, commit }, { server, id }) => {
    commit('SERVICE_REQUEST', { server, id })
    return api(state, server).service(id).then(service => {
      commit('SERVICE_SUCCESS', { server, id, service })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response } = err
      commit('SERVICE_ERROR', response)
      throw err
    })
  },
  disableService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_DISABLING', { server, id })
    return api(state, server).disable(id).then(response => {
      commit('SERVICE_DISABLED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: error } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    }).finally(() => dispatch('getService', { server, id }))
  },
  enableService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_ENABLING', { server, id })
    return api(state, server).enable(id).then(response => {
      commit('SERVICE_ENABLED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: error } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    }).finally(() => dispatch('getService', { server, id }))
  },
  restartService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_RESTARTING', { server, id })
    return api(state, server).restart(id).then(response => {
      commit('SERVICE_RESTARTED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: error } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    }).finally(() => dispatch('getService', { server, id }))
  },
  startService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_STARTING', { server, id })
    return api(state, server).start(id).then(response => {
      commit('SERVICE_STARTED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: error } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    }).finally(() => dispatch('getServices', { server, id }))
  },
  stopService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_STOPPING', { server, id })
    return api(state, server).stop(id).then(response => {
      commit('SERVICE_STOPPED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: error } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    }).finally(() => dispatch('getService', { server, id }))
  },

  restartSystemService: ({ state, commit }, { server, id }) => {
    commit('SYSTEM_SERVICE_RESTARTING', { server, id })
    return api(state, server).restartSystem(id).then(response => {
      commit('SYSTEM_SERVICE_RESTARTED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: error } = err
      commit('SYSTEM_SERVICE_ERROR', { server, id, error })
      throw err
    })
  },
  startSystemService: ({ state, commit }, { server, id }) => {
    commit('SYSTEM_SERVICE_STARTING', { server, id })
    return api(state, server).startSystem(id).then(response => {
      commit('SYSTEM_SERVICE_STARTED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: error } = err
      commit('SYSTEM_SERVICE_ERROR', { server, id, error })
      throw err
    })
  },
  stopSystemService: ({ state, commit }, { server, id }) => {
    commit('SYSTEM_SERVICE_STOPPING', { server, id })
    return api(state, server).stopSystem(id).then(response => {
      commit('SYSTEM_SERVICE_STOPPED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: error } = err
      commit('SYSTEM_SERVICE_ERROR', { server, id, error })
      throw err
    })
  },
  updateSystemd: ({ state, commit }, { server, id }) => {
    commit('SYSTEMD_REQUEST', { server, id })
    return api(state, server).updateSystemd(id).then(response => {
      commit('SYSTEMD_SUCCESS', { server, id, response })
      return response
    }).catch(err => {
      const { response: error } = err
      commit('SYSTEMD_ERROR', { server, id, error })
      throw err
    })
  },
}

const mutations = {
  CONFIG_REQUEST: state => {
    state.status = types.LOADING
    state.message = ''
  },
  CONFIG_SUCCESS: (state, item) => {
    const { CLUSTER, ...servers } = item
    state.config = CLUSTER
    Object.keys(servers).map(server => {
      Vue.set(state.servers, server, { services: {}, ...state.servers[server], ...item[server] })
    })
    state.status = types.SUCCESS
  },
  CONFIG_ERROR: (state, error) => {
    state.message = error
    state.status = types.ERROR
  },

  SERVICES_REQUEST: (state, server) => {
    Vue.set(state.servers, server, state.servers[server] || {})
    state.status = types.LOADING
    state.message = ''
  },
  SERVICES_SUCCESS: (state, { server, services }) => {
    const _services = services.reduce((assoc, service) => {
      const { id } = service
      service.pid = parseInt(service.pid)
      // merge, don't squash
      return { ...assoc, [id]: { ...assoc[id], ...service } }
    }, state.servers[server].services)
    Vue.set(state.servers[server], 'services', _services)
  },
  SERVICES_ERROR: (state, error) => {
    state.message = error
    state.status = types.ERROR
  },

  SERVICE_REQUEST: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers, server, { services: { [id]: { status: types.LOADING } }, ...state.servers[server] })
  },
  SERVICE_SUCCESS: (state, { server, id, service }) => {
    service.pid = parseInt(service.pid)
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services, id, { ...state.servers[server].services[id], ...service, status: types.SUCCESS })
  },
  SERVICE_DISABLING: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers, server, { services: { [id]: { status: types.DISABLING } }, ...state.servers[server] })
  },
  SERVICE_DISABLED: (state, { server, id }) => {
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services[id], 'enabled', false)
    Vue.set(state.servers[server].services[id], 'status', types.SUCCESS)
  },
  SERVICE_ENABLING: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers, server, { services: { [id]: { status: types.ENABLING } }, ...state.servers[server] })
  },
  SERVICE_ENABLED: (state, { server, id }) => {
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services[id], 'enabled', true)
    Vue.set(state.servers[server].services[id], 'status', types.SUCCESS)
  },
  SERVICE_RESTARTING: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers, server, { services: { [id]: { status: types.RESTARTING } }, ...state.servers[server] })
  },
  SERVICE_RESTARTED: (state, { server, id, response }) => {
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services[id], 'pid', parseInt(response.pid))
    Vue.set(state.servers[server].services[id], 'alive', true)
    Vue.set(state.servers[server].services[id], 'status', types.SUCCESS)
  },
  SERVICE_STARTING: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers, server, { services: { [id]: { status: types.STARTING } }, ...state.servers[server] })
  },
  SERVICE_STARTED: (state, { server, id, response }) => {
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services[id], 'pid', parseInt(response.pid))
    Vue.set(state.servers[server].services[id], 'alive', true)
    Vue.set(state.servers[server].services[id], 'status', types.SUCCESS)
  },
  SERVICE_STOPPING: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers, server, { services: { [id]: { status: types.STOPPING } }, ...state.servers[server] })
  },
  SERVICE_STOPPED: (state, { server, id }) => {
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services[id], 'pid', 0)
    Vue.set(state.servers[server].services[id], 'alive', false)
    Vue.set(state.servers[server].services[id], 'status', types.SUCCESS)
  },
  SERVICE_ERROR: (state, { server, id }) => {
    state.status = types.ERROR
    Vue.set(state.servers[server].services[id], 'status', types.ERROR)
  },

  SYSTEM_SERVICE_RESTARTING: state => {
    state.status = types.RESTARTING
  },
  SYSTEM_SERVICE_RESTARTED: state => {
    state.status = types.SUCCESS
  },
  SYSTEM_SERVICE_STARTING: state => {
    state.status = types.STARTING
  },
  SYSTEM_SERVICE_STARTED: state => {
    state.status = types.SUCCESS
  },
  SYSTEM_SERVICE_STOPPING: state => {
    state.status = types.STOPPING
  },
  SYSTEM_SERVICE_STOPPED: state => {
    state.status = types.SUCCESS
  },
  SYSTEM_SERVICE_ERROR: (state, error) => {
    state.status = types.ERROR
    state.message = error
  },

  SYSTEMD_REQUEST: state => {
    state.status = types.LOADING
    state.message = ''
  },
  SYSTEMD_SUCCESS: state => {
    state.status = types.SUCCESS
  },
  SYSTEMD_ERROR: (state, error) => {
    state.message = error
    state.status = types.ERROR
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