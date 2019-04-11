import Vue from 'vue'
import api from '../_api'

const STORAGE_CHARTS_KEY = 'dashboard-charts'

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

const state = {
  allCharts: [],
  allChartsStatus: '',
  charts: localStorage.getItem(STORAGE_CHARTS_KEY) ? JSON.parse(localStorage.getItem(STORAGE_CHARTS_KEY)) : [],
  services: [],
  servicesStatus: '',
  cluster: null,
  clusterStatus: ''
}

const getters = {
  isLoading: state => state.allChartsStatus === types.LOADING,
  allModules: state => {
    let modules = []
    let unasignedCharts = false
    for (const chart of state.allCharts) {
      if (chart.module && !modules.includes(chart.module)) {
        modules.push(chart.module)
      } else if (!chart.module) {
        unasignedCharts = true
      }
    }
    if (unasignedCharts) {
      modules.push('other')
    }
    return modules
  }
}

const actions = {
  allCharts: ({ state, commit }) => {
    if (state.allCharts.length > 0) {
      return Promise.resolve(state.allCharts)
    }
    if (state.allChartsStatus !== types.LOADING) {
      commit('ALL_CHARTS_REQUEST')
      return api.charts().then(charts => {
        commit('ALL_CHARTS_UPDATED', charts)
      }).catch(err => {
        commit('ALL_CHARTS_ERROR')
        commit('session/CHARTS_ERROR', err.response, { root: true })
      })
    }
  },
  getChart: ({ commit }, id) => {
    return api.chart(id).catch(err => {
      commit('ALL_CHARTS_ERROR')
      commit('session/CHARTS_ERROR', err.response, { root: true })
    })
  },
  addChart: ({ state, commit }, definition) => {
    let chart = {
      id: definition.id,
      name: definition.name,
      title: definition.title,
      library: definition.library,
      cols: definition.cols
    }
    commit('CHARTS_UPDATED', chart)
    localStorage.setItem(STORAGE_CHARTS_KEY, JSON.stringify(state.charts))
  },
  getServices: ({ state, commit }) => {
    if (state.services.length > 0) {
      return Promise.resolve(state.services)
    }
    if (state.servicesStatus !== types.LOADING) {
      commit('SERVICES_REQUEST')
      return api.services().then(services => {
        commit('SERVICES_UPDATED', services)
        for (let [index, service] of state.services.entries()) {
          commit('SERVICE_REQUEST', index)
          api.service(service.name, 'status').then(status => {
            commit('SERVICE_UPDATED', { index, status })
          })
        }
      }).catch(err => {
        commit('SERVICES_ERROR')
        commit('session/API_ERROR', err.response, { root: true })
      })
    }
  },
  getCluster: ({ state, commit }) => {
    if (state.cluster) {
      return state.cluster
    }
    if (state.clusterStatus !== types.LOADING) {
      commit('CLUSTER_REQUEST')
      return api.cluster().then(servers => {
        commit('CLUSTER_UPDATED', servers)
        return servers
      }).catch(() => {
        commit('CLUSTER_ERROR')
      })
    }
  }
}

const mutations = {
  ALL_CHARTS_REQUEST: (state) => {
    state.allChartsStatus = types.LOADING
  },
  ALL_CHARTS_UPDATED: (state, charts) => {
    state.allChartsStatus = types.SUCCESS
    state.allCharts = charts
  },
  ALL_CHARTS_ERROR: (state) => {
    state.allChartsStatus = types.ERROR
    state.allCharts = []
  },
  CHARTS_UPDATED: (state, chart) => {
    if (state.charts.filter(c => c.id === chart.id).length) {
      // eslint-disable-next-line
      console.warn('chart ' + chart.id + ' already on dashboard')
    } else {
      state.charts.push(chart)
    }
  },
  SERVICES_REQUEST: (state) => {
    state.servicesStatus = types.LOADING
  },
  SERVICES_UPDATED: (state, services) => {
    state.servicesStatus = types.SUCCESS
    state.services = services.map(name => {
      return { name }
    })
  },
  SERVICES_ERROR: (state) => {
    state.servicesStatus = types.ERROR
  },
  SERVICE_REQUEST: (state, index) => {
    Vue.set(state.services, index, Object.assign(state.services[index], { loading: true }))
  },
  SERVICE_UPDATED: (state, data) => {
    data.status.enabled = data.status.enabled === 1
    data.status.alive = data.status.alive === 1
    data.status.loading = false
    Vue.set(state.services, data.index, Object.assign(state.services[data.index], data.status))
  },
  CLUSTER_REQUEST: (state) => {
    state.clusterStatus = types.LOADING
  },
  CLUSTER_UPDATED: (state, servers) => {
    state.clusterStatus = types.SUCCESS
    if (servers.length > 0) {
      state.cluster = servers
    } else {
      state.cluster = [{ host: 'localhost', management_ip: '127.0.0.1' }]
    }
  },
  CLUSTER_ERROR: (state) => {
    state.clusterStatus = types.ERROR
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
