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
  getServices: ({commit}) => {
    api.services().then(services => {
      commit('SERVICES_UPDATED', services)
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
      state.charts.push(chart)
    }
  },
  SERVICES_UPDATED: (state, services) => {
    state.services = services
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
