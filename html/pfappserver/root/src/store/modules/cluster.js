/**
* "cluster" store module
*/
import Vue from 'vue'
import store from '@/store'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'

const api = (state, server = store.state.system.hostname) => {
  let headers = {}

  if (server && state.cluster) { // is cluster
    const { servers: { [server]: { management_ip } = {} } = {} } = state
    if (management_ip) {
      headers['X-PacketFence-Server'] = management_ip
    }
  }

  return {
    config: () => {
      return apiCall.get('cluster/servers').then(response => {
        return response.data.items
      })
    },
    services: () => {
      if (state.cluster) { // is cluster
        return apiCall.getQuiet(`services/cluster_status/${server}`).then(response => {
          return response.data.item.services
        })
      }
      else { // no cluster
        return apiCall.getQuiet('services/status_all').then(response => {
          return response.data.items
        })
      }
    },
    service: id => {
      return apiCall.getQuiet(['service', id, 'status'], { headers }).then(response => {
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

export const protectedServices = [ // prevent start|stop|restart control on these services
  'api-frontend',
  'pf',
  'pfperl-api',
  'haproxy-admin',
  'httpd.admin_dispatcher'
]

// Default values
const initialState = () => {
  return {
    cluster: false,
    servers: {},
    message: '',
    status: ''
  }
}

const getters = {
  isCluster: state => Object.keys(state.servers).length > 1,
  isLoading: state => state.status === types.LOADING,
  clusterIPs: state => Object.values(state.servers).map(server => server.management_ip),
  servicesByServer: state => {
    return Object.entries(state.servers).reduce((sorted, [server, {services = {}}]) => {
      return Object.entries(services).reduce((sorted, [id, service]) => {
        return {
          ...sorted,
          [id]: {
            servers: {
               ...((id in sorted) ? sorted[id].servers : {} ),
              [server]: {
                ...service,
                isDisabling: service.status === types.DISABLING,
                isEnabling: service.status === types.ENABLING,
                isRestarting: service.status === types.RESTARTING,
                isStarting: service.status === types.STARTING,
                isStopping: service.status === types.STOPPING,
              }
            },
            hasAlive: Object.values(state.servers).findIndex(({ services: { [id]: service } }) => service && service.alive && service.pid) > -1,
            hasDead: Object.values(state.servers).findIndex(({ services: { [id]: service } }) => service && !(service.alive || service.pid)) > -1,
            hasEnabled: Object.values(state.servers).findIndex(({ services: { [id]: service } }) => service && service.enabled) > -1,
            hasDisabled: Object.values(state.servers).findIndex(({ services: { [id]: service } }) => service && !service.enabled) > -1,
            isProtected: !!protectedServices.find(listed => listed === id),
          }
        }
      }, sorted)
    }, {})
  }
}

const actions = {
  getConfig: ({ state, commit, dispatch }, withServices) => {
    commit('CONFIG_REQUEST')
    return api(state).config().then(items => {
      if (items.length) {
        // is cluster
        commit('CONFIG_IS_CLUSTER')
      }
      else {
        // no cluster
        items = store.dispatch('system/getHostname').then(host => {
          return [
            { host, management_ip: "127.0.0.1" }
          ]
        })
      }
      return Promise.resolve(items).then(items => {
        commit('CONFIG_SUCCESS', items)
        if (withServices) {
          let promises = []
          items.map(server => {
            promises.push(dispatch('getServices', server.host))
          })
          return Promise.all(promises).then(() => {
           return state.cluster
          })
        }
        return state.cluster
      })
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
      const { response: { data: { message: error } = {} } = {} } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    })
  },
  getServiceCluster: ({ state, dispatch }, id) => {
    return dispatch('getConfig').then(() => {
      let promises = []
      Object.keys(state.servers).map(server => {
        promises.push(dispatch('getService', { server, id }))
      })
      return Promise.all(promises).then(servers => {
        return servers.reduce((assoc, service, index) => {
          const server = Object.keys(state.servers)[index]
          return { ...assoc, [server]: state.servers[server].services[id] }
        }, {})
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
      const { response: { data: error } = {} } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    }).finally(() => dispatch('getService', { server, id }))
  },
  disableServiceCluster: ({ state, dispatch }, id) => {
    return new Promise((resolve, reject) => {
      dispatch('getConfig').then(() => {
        // async requests
        const async = (idx = 0) => {
          const server = Object.keys(state.servers)[idx]
          const next = () => {
            if (idx < Object.keys(state.servers).length - 1) {
              async(++idx)
            }
            else {
              resolve()
            }
          }
          const { [server]: { services: { [id]: { enabled = false } = {} } = {} } = {} } = state.servers
          if (enabled) {
            dispatch('disableService', { server, id })
             .catch(err => reject(err))
             .then(() => next())
          }
          else {
            next()
          }
        }
        async()
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
      const { response: { data: error } = {} } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    }).finally(() => dispatch('getService', { server, id }))
  },
  enableServiceCluster: ({ state, dispatch }, id) => {
    return new Promise((resolve, reject) => {
      dispatch('getConfig').then(() => {
        // async requests
        const async = (idx = 0) => {
          const server = Object.keys(state.servers)[idx]
          const next = () => {
            if (idx < Object.keys(state.servers).length - 1) {
              async(++idx)
            }
            else {
              resolve()
            }
          }
          const { [server]: { services: { [id]: { enabled = false } = {} } = {} } = {} } = state.servers
          if (!enabled) {
            dispatch('enableService', { server, id })
             .catch(err => reject(err))
             .then(() => next())
          }
          else {
            next()
          }
        }
        async()
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
      const { response: { data: error } = {} } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    }).finally(() => dispatch('getService', { server, id }))
  },
  restartServiceCluster: ({ state, dispatch }, id) => {
    return new Promise((resolve, reject) => {
      dispatch('getConfig').then(() => {
        // async requests
        const async = (idx = 0) => {
          const server = Object.keys(state.servers)[idx]
          const next = () => {
            if (idx < Object.keys(state.servers).length-1) {
              async(++idx)
            }
            else {
              resolve()
            }
          }
          const { [server]: { services: { [id]: { alive = false, pid = false } = {} } = {} } = {} } = state.servers
          if (alive && pid) {
            dispatch('restartService', { server, id })
             .catch(err => reject(err))
              .then(() => next())
          }
          else {
             next()
          }
        }
        async()
      })
    })
  },
  startService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_REQUEST', { server, id })
    commit('SERVICE_STARTING', { server, id })
    return api(state, server).start(id).then(response => {
      commit('SERVICE_STARTED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    }).finally(() => dispatch('getService', { server, id }))
  },
  startServiceCluster: ({ state, dispatch }, id) => {
    return new Promise((resolve, reject) => {
      dispatch('getConfig').then(() => {
        // async requests
        const async = (idx = 0) => {
          const server = Object.keys(state.servers)[idx]
          const next = () => {
            if (idx < Object.keys(state.servers).length - 1) {
              async(++idx)
            }
            else {
              resolve()
            }
          }
          const { [server]: { services: { [id]: { alive = false, pid = false } = {} } = {} } = {} } = state.servers
          if (!(alive && pid)) {
            dispatch('startService', { server, id })
             .catch(err => reject(err))
             .then(() => next())
          }
          else {
            next()
          }
        }
        async()
      })
    })
  },
  stopService: ({ state, commit, dispatch }, { server, id }) => {
    commit('SERVICE_REQUEST', { server, id })
    commit('SERVICE_STOPPING', { server, id })
    return api(state, server).stop(id).then(response => {
      commit('SERVICE_STOPPED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('SERVICE_ERROR', { server, id, error })
      throw err
    }).finally(() => dispatch('getService', { server, id }))
  },
  stopServiceCluster: ({ state, dispatch }, id) => {
    return new Promise((resolve, reject) => {
      dispatch('getConfig').then(() => {
        // async requests
        const async = (idx = 0) => {
          const server = Object.keys(state.servers)[idx]
          const next = () => {
            if (idx < Object.keys(state.servers).length - 1) {
              async(++idx)
            }
            else {
              resolve()
            }
          }
          const { [server]: { services: { [id]: { alive = false, pid = false } = {} } = {} } = {} } = state.servers
          if (alive && pid) {
            dispatch('stopService', { server, id })
             .catch(err => reject(err))
             .then(() => next())
          }
          else {
            next()
          }
        }
        async()
      })
    })
  },

  restartSystemService: ({ state, commit }, { id, server = store.state.system.hostname }) => {
    commit('SYSTEM_SERVICE_RESTARTING', { server, id })
    return api(state, server).restartSystem(id).then(response => {
      commit('SYSTEM_SERVICE_RESTARTED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('SYSTEM_SERVICE_ERROR', { server, id, error })
      throw err
    })
  },
  startSystemService: ({ state, commit }, { id, server = store.state.system.hostname }) => {
    commit('SYSTEM_SERVICE_STARTING', { server, id })
    return api(state, server).startSystem(id).then(response => {
      commit('SYSTEM_SERVICE_STARTED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('SYSTEM_SERVICE_ERROR', { server, id, error })
      throw err
    })
  },
  stopSystemService: ({ state, commit }, { id, server = store.state.system.hostname }) => {
    commit('SYSTEM_SERVICE_STOPPING', { server, id })
    return api(state, server).stopSystem(id).then(response => {
      commit('SYSTEM_SERVICE_STOPPED', { server, id, response })
      return state.servers[server].services[id]
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('SYSTEM_SERVICE_ERROR', { server, id, error })
      throw err
    })
  },
  updateSystemd: ({ state, commit }, { id, server = store.state.system.hostname }) => {
    commit('SYSTEMD_REQUEST', { server, id })
    return api(state, server).updateSystemd(id).then(response => {
      commit('SYSTEMD_SUCCESS', { server, id, response })
      return response
    }).catch(err => {
      const { response: { data: error } = {} } = err
      commit('SYSTEMD_ERROR', { server, id, error })
      throw err
    })
  },
}

const mutations = {
  CONFIG_REQUEST: state => {
    state.status = types.LOADING
  },
  CONFIG_IS_CLUSTER: state => {
    state.cluster = true
  },
  CONFIG_SUCCESS: (state, items) => {
    items.map(server => {
      Vue.set(state.servers, server.host, { services: {}, ...state.servers[server.host], ...server })
    })
    state.status = types.SUCCESS
    state.message = ''
  },
  CONFIG_ERROR: (state, error) => {
    state.status = types.ERROR
    state.message = error
  },

  SERVICES_REQUEST: (state, server) => {
    Vue.set(state.servers, server, state.servers[server] || {})
    state.status = types.LOADING
  },
  SERVICES_SUCCESS: (state, { server, services }) => {
    const _services = services.reduce((assoc, service) => {
      const { id } = service
      service.pid = parseInt(service.pid)
      // merge, don't squash
      return { ...assoc, [id]: { ...assoc[id], ...service } }
    }, state.servers[server].services)
    Vue.set(state.servers[server], 'services', _services)
    state.status = types.SUCCESS
    state.message = ''
  },
  SERVICES_ERROR: (state, error) => {
    state.status = types.ERROR
    state.message = error
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
    Vue.delete(state.servers[server].services[id], 'message')
  },
  SERVICE_ENABLING: (state, { server, id }) => {
    state.status = types.LOADING
    Vue.set(state.servers[server].services[id], 'status', types.ENABLING)
  },
  SERVICE_ENABLED: (state, { server, id }) => {
    state.status = types.SUCCESS
    Vue.set(state.servers[server].services[id], 'enabled', true)
    Vue.set(state.servers[server].services[id], 'status', types.SUCCESS)
    Vue.delete(state.servers[server].services[id], 'message')
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
    Vue.delete(state.servers[server].services[id], 'message')
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
    Vue.delete(state.servers[server].services[id], 'message')
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
    Vue.delete(state.servers[server].services[id], 'message')
  },
  SERVICE_ERROR: (state, { server, id, error }) => {
    state.status = types.ERROR
    Vue.set(state.servers[server].services[id], 'status', types.ERROR)
    const { message } = error
    if (message) {
      error = (message.consructor === String) ? JSON.parse(message) : message
      Vue.set(state.servers[server].services[id], 'message', error)
    }
    else {
      Vue.set(state.servers[server].services[id], 'message', error)
    }
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
  },
  SYSTEMD_SUCCESS: state => {
    state.status = types.SUCCESS
    state.message = ''
  },
  SYSTEMD_ERROR: (state, error) => {
    state.status = types.ERROR
    state.message = error
  },
  $RESET: (state) => {
    // eslint-disable-next-line no-unused-vars
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
