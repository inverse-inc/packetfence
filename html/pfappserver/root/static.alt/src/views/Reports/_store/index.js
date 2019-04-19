/**
* "$_reports" store module
*/
import Vue from 'vue'
import api from '../_api'

// Default values
const state = {
  reports: {}, // reports details
  reportStatus: '',
  message: ''
}

const getters = {
  isLoading: state => state.reportStatus === 'loading'
}

const actions = {
  all: () => {
    const params = {
      sort: ['id'],
      fields: ['id', 'description', 'long_description', 'type']
    }
    return api.reports(params).then(response => {
      return response.items
    })
  },
  getReport: ({ state, commit }, id) => {
    if (state.reports[id]) {
      return Promise.resolve(state.reports[id])
    }
    commit('REPORT_REQUEST')
    return api.report(id).then(response => {
      commit('REPORT_REPLACED', response)
      return response
    })
  },
  searchReport: ({ commit }, data) => {
    commit('REPORT_REQUEST')
    return new Promise((resolve, reject) => {
      api.searchReport(data).then(response => {
        commit('REPORT_SUCCESS')
        resolve(response)
      }).catch(err => {
        commit('REPORT_ERROR', err.response)
        reject(err)
      })
    })
  }
}

const mutations = {
  REPORT_REQUEST: (state) => {
    state.reportStatus = 'loading'
    state.message = ''
  },
  REPORT_REPLACED: (state, data) => {
    state.reportStatus = 'success'
    Vue.set(state.reports, data.id, data)
  },
  REPORT_SUCCESS: (state) => {
    state.reportStatus = 'success'
  },
  REPORT_ERROR: (state, response) => {
    state.reportStatus = 'error'
    if (response && response.data) {
      state.message = response.data.message
    }
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
