/**
* "$_status" store module
*/
import Vue from 'vue'
import store from '@/store'
import api from '../_api'
import { types } from '@/store'
import { blacklistedServices } from '@/store/modules/services'

const STORAGE_CHARTS_KEY = 'dashboard-charts'

const state = () => {
  return {
    allCharts: {},
    allChartsStatus: '',
    charts: localStorage.getItem(STORAGE_CHARTS_KEY) ? JSON.parse(localStorage.getItem(STORAGE_CHARTS_KEY)) : [],
    alarmsStatus: '',
    alarms: {}
  }
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
  },
  uniqueCharts: state => {
    let charts = [].concat(...Object.values(state.allCharts))
    // Remove duplicates
    for (let i = 0; i < charts.length; ++i) {
      for (let j = i + 1; j < charts.length; ++j) {
          if (charts[i].id === charts[j].id)
          charts.splice(j--, 1);
      }
    }
    return charts
  },
  hostsForChart: state => id => {
    return Object.keys(state.allCharts).filter(ip => {
      return state.allCharts[ip].find(chart => chart.id === id)
    })
  }
}

const actions = {
  allCharts: ({ state, getters, commit }) => {
    if (state.allCharts.length > 0) {
      return Promise.resolve(state.allCharts)
    }
    if (state.allChartsStatus !== types.LOADING) {
      commit('ALL_CHARTS_REQUEST')
      // Assume cluster/getConfig has been dispatched
      return Promise.all(store.getters['cluster/clusterIPs'].map(ip => {
        return api.charts(ip).then(charts => {
          commit('ALL_CHARTS_UPDATED', { [ip]: charts })
        }).catch(err => {
          commit('ALL_CHARTS_ERROR')
          commit('session/CHARTS_ERROR', err.response, { root: true })
          throw err
        })
      }))
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
  alarms: ({ state, commit }, ip) => {
    if (state.alarmsStatus !== types.LOADING) {
      commit('ALARMS_REQUEST')
      return api.alarms(ip).then(data => {
        commit('ALARMS_UPDATED', data)
        return data
      }).catch(err => {
        commit('ALARMS_ERROR')
        commit('session/CHARTS_ERROR', err.response, { root: true })
      })
    }
    throw new Error('$_status/alarms: another task is already in progress')
  }
}

const mutations = {
  ALL_CHARTS_REQUEST: (state) => {
    state.allChartsStatus = types.LOADING
  },
  ALL_CHARTS_UPDATED: (state, charts) => {
    const [ first ] = Object.keys(charts)
    state.allChartsStatus = types.SUCCESS
    Vue.set(state.allCharts, first, charts[first])
  },
  ALL_CHARTS_ERROR: (state) => {
    state.allChartsStatus = types.ERROR
    state.allCharts = {}
  },
  CHARTS_UPDATED: (state, chart) => {
    if (state.charts.filter(c => c.id === chart.id).length) {
      // eslint-disable-next-line
      console.warn('chart ' + chart.id + ' already on dashboard')
    } else {
      state.charts.push(chart)
    }
  },
  ALARMS_REQUEST: (state) => {
    state.alarmsStatus = types.LOADING
  },
  ALARMS_UPDATED: (state) => {
    state.alarmsStatus = types.SUCCESS
    // state.alarms = alarms // no caching necessary for now
  },
  ALARMS_ERROR: (state) => {
    state.alarmsStatus = types.ERROR
    state.alarms = {}
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
