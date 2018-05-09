import Vue from 'vue'
import api from '../_api'

const STORAGE_CHARTS_KEY = 'dashboard-charts'

const state = {
  allCharts: [],
  charts: localStorage.getItem(STORAGE_CHARTS_KEY) ? JSON.parse(localStorage.getItem(STORAGE_CHARTS_KEY)) : [],
  services: []
}

const getters = {
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
  allCharts: ({commit}, query) => {
    api.charts().then(charts => {
      commit('ALL_CHARTS_SUCCESS', charts)
    }).catch(err => {
      commit('session/CHARTS_ERROR', err.response, { root: true })
    })
  },
  addChart: ({state, commit}, definition) => {
    console.debug('adding chart ' + definition.id)
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
  getServices: ({state, commit}) => {
    api.services().then(services => {
      commit('SERVICES_UPDATED', services)
      for (let [index, service] of state.services.entries()) {
        commit('SERVICE_REQUEST', index)
        api.service(service.name, 'status').then(status => {
          commit('SERVICE_UPDATED', { index, status })
        })
      }
    }).catch(err => {
      commit('session/API_ERROR', err.response, { root: true })
    })
  }
}

const mutations = {
  ALL_CHARTS_SUCCESS: (state, charts) => {
    state.allCharts = charts
  },
  CHARTS_UPDATED: (state, chart) => {
    if (state.charts.filter(c => c.id === chart.id).length) {
      console.warn('chart ' + chart.id + ' already on dashboard')
    } else {
      state.charts.push(chart)
    }
  },
  SERVICES_UPDATED: (state, services) => {
    state.services = services.map(name => {
      return { name }
    })
  },
  SERVICE_REQUEST: (state, index) => {
    Vue.set(state.services, index, Object.assign(state.services[index], { loading: true }))
  },
  SERVICE_UPDATED: (state, data) => {
    data.status.enabled = data.status.enabled === 1
    data.status.alive = data.status.alive === 1
    data.status.loading = false
    Vue.set(state.services, data.index, Object.assign(state.services[data.index], data.status))
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
