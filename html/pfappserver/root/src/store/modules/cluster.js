/**
* "cluster" store module
*/
import Vue from 'vue'
import store from '@/store'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'

const api = (state, server) => {
  let headers = {}
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
      return apiCall.get(['service', id, 'status'], { headers }).then(response => {
        return response.data
      })
    },
    disable: id => {
      return apiCall.postQuiet(['service', id, 'disable'], { headers }).then(response => {
        const { data: { disable } } = response
        if (parseInt(disable) > 0) {
          return response.data
        }
        else {
          throw new Error(i18n.t(`Could not disable {id} on {server}.`, { server, id }))
        }
      })
    },
    enable: id => {
      return apiCall.postQuiet(['service', id, 'enable'], { headers }).then(response => {
        const { data: { enable } } = response
        if (parseInt(enable) > 0) {
          return response.data
        }
        else {
          throw new Error(i18n.t(`Could not enable {id} on {server}.`, { server, id }))
        }
      })
    },
    restart: id => {
      return apiCall.postQuiet(['service', id, 'restart'], { async: true }, { headers })
        .then(response => {
          const { data: { task_id } = {} } = response
          return store.dispatch('pfqueue/pollTaskStatus', { task_id, headers }).then(response => {
            const { restart } = response
            if (parseInt(restart) > 0) {
              return response
            }
            else {
              throw new Error(i18n.t(`Could not restart {id} on {server}.`, { server, id }))
            }
          })
        })
    },
    start: id => {
      return apiCall.postQuiet(['service', id, 'start'], { async: true }, { headers })
        .then(response => {
          const { data: { task_id } = {} } = response
          return store.dispatch('pfqueue/pollTaskStatus', { task_id, headers }).then(response => {
            const { start } = response
            if (parseInt(start) > 0) {
              return response
            }
            else {
              throw new Error(i18n.t(`Could not start {id} on {server}.`, { server, id }))
            }
          })
        })
    },
    stop: id => {
      return apiCall.postQuiet(['service', id, 'stop'], { async: true }, { headers })
        .then(response => {
          const { data: { task_id } = {} } = response
          return store.dispatch('pfqueue/pollTaskStatus', { task_id, headers }).then(response => {
            const { stop } = response
            if (parseInt(stop) > 0) {
              return response
            }
            else {
              throw new Error(i18n.t(`Could not stop {id} on {server}.`, { server, id }))
            }
          })
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
  isLoading: state => state.status === types.LOADING,
  servicesByServer: state => Object.keys(state.servers).reduce((services, server) => {
    Object.keys(state.servers[server].services).map(id => {
      services[id] = { ...services[id], [server]: state.servers[server].services[id] }
    })
    return services
  }, {})
}

const actions = {
  getConfig: ({ state, commit, dispatch }, withServices) => {
    commit('CONFIG_REQUEST')
    return api(state).config().then(item => {
      commit('CONFIG_SUCCESS', item)
      const { CLUSTER, ...servers } = item
      if (withServices) {
        let promises = []
        Object.keys(servers).map(server => {
          promises.push(dispatch('getServices', server))
        })
        return Promise.all(promises).then(() => state.config)
      }
      return state.config
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
  getServiceCluster: ({ state, dispatch }, id) => {
    dispatch('getConfig').then(() => {
/*
      // async requests
      const async = (idx = 0) => {
        dispatch('getService', { server: state.servers[idx], id })
          .finally(() => {
            if (idx < state.servers.length-1) {
              async(++idx)
            }
          })
      }
      async()
*/
      Object.keys(state.servers).map(server => {
        dispatch('getService', { server, id })
      })
    })
  },
  disableService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_REQUEST', { server, id })
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
  disableServiceCluster: ({ state, dispatch }, id) => {
    dispatch('getConfig').then(() => {
      Object.keys(state.servers).map(server => {
        dispatch('disableService', { server, id })
      })
    })
  },
  enableService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_REQUEST', { server, id })
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
  enableServiceCluster: ({ state, dispatch }, id) => {
    dispatch('getConfig').then(() => {
      Object.keys(state.servers).map(server => {
        dispatch('enableService', { server, id })
      })
    })
  },
  restartService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_REQUEST', { server, id })
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
  restartServiceCluster: ({ state, dispatch }, id) => {
    dispatch('getConfig').then(() => {
      // async requests
      const async = (idx = 0) => {
        dispatch('restartService', { server: state.servers[idx], id })
          .finally(() => {
            if (idx < state.servers.length-1) {
              async(++idx)
            }
          })
      }
      async()
    })
  },
  startService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_REQUEST', { server, id })
    commit('SERVICE_STARTING', { server, id })
    return api(state, server).start(id).then(response => {
      commit('SERVICE_STARTED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: error } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    }).finally(() => dispatch('getService', { server, id }))
  },
  startServiceCluster: ({ state, dispatch }, id) => {
    dispatch('getConfig').then(() => {
      // async requests
      const async = (idx = 0) => {
        dispatch('startService', { server: state.servers[idx], id })
          .finally(() => {
            if (idx < state.servers.length-1) {
              async(++idx)
            }
          })
      }
      async()
    })
  },
  stopService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_REQUEST', { server, id })
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
  stopServiceCluster: ({ state, dispatch }, id) => {
    dispatch('getConfig').then(() => {
      // async requests
      const async = (idx = 0) => {
        dispatch('stopService', { server: state.servers[idx], id })
          .finally(() => {
            if (idx < state.servers.length-1) {
              async(++idx)
            }
          })
      }
      async()
    })
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
    Vue.set(state.servers, server, state.servers[server] || { services: {} })
    Vue.set(state.servers[server].services, id, state.servers[server].services[id] || {})
    Vue.set(state.servers[server].services[id], 'status', types.LOADING)
  },
  SERVICE_SUCCESS: (state, { server, id, service }) => {
    service.pid = parseInt(service.pid)
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services, id, { ...state.servers[server].services[id], ...service, status: types.SUCCESS })
  },
  SERVICE_DISABLING: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers[server].services[id], 'status', types.DISABLING)
  },
  SERVICE_DISABLED: (state, { server, id }) => {
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services[id], 'enabled', false)
    Vue.set(state.servers[server].services[id], 'status', types.SUCCESS)
  },
  SERVICE_ENABLING: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers[server].services[id], 'status', types.ENABLING)
  },
  SERVICE_ENABLED: (state, { server, id }) => {
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services[id], 'enabled', true)
    Vue.set(state.servers[server].services[id], 'status', types.SUCCESS)
  },
  SERVICE_RESTARTING: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers[server].services[id], 'status', types.RESTARTING)
  },
  SERVICE_RESTARTED: (state, { server, id, response }) => {
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services[id], 'pid', parseInt(response.pid))
    Vue.set(state.servers[server].services[id], 'alive', true)
    Vue.set(state.servers[server].services[id], 'status', types.SUCCESS)
  },
  SERVICE_STARTING: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers[server].services[id], 'status', types.STARTING)
  },
  SERVICE_STARTED: (state, { server, id, response }) => {
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services[id], 'pid', parseInt(response.pid))
    Vue.set(state.servers[server].services[id], 'alive', true)
    Vue.set(state.servers[server].services[id], 'status', types.SUCCESS)
  },
  SERVICE_STOPPING: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers[server].services[id], 'status', types.STOPPING)
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