/**
* "pfqueue" store module
*/
import Vue from 'vue'
import apiCall from '@/utils/api'

const api = {
  getStats: (id) => {
    return apiCall.getQuiet(`queues/stats`).then(response => {
      return response.data.items
    })
  }
}

const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const state = {
  stats: false,
  message: '',
  requestStatus: ''
}

const getters = {
  isLoading: state => state.requestStatus === types.LOADING,
  stats: state => state.stats || []
}

const actions = {
  getStats: ({ commit, state }) => {
    commit('PFQUEUE_REQUEST')
    return new Promise((resolve, reject) => {
      api.getStats().then(data => {
        commit('PFQUEUE_SUCCESS', data)
        resolve(state.stats)
      }).catch(err => {
        commit('PFQUEUE_ERROR', err.response)
        reject(err)
      })
    })
  }
}

const mutations = {
  PFQUEUE_REQUEST: (state) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  PFQUEUE_SUCCESS: (state, data) => {
    Vue.set(state, 'stats', data)
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  PFQUEUE_ERROR: (state, data) => {
    state.requestStatus = types.ERROR
    const { response: { data: { message } = {} } = {} } = data
    if (message) {
      state.message = message
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
