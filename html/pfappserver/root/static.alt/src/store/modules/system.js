/**
* "system" store module
*/
import Vue from 'vue'
import i18n from '@/utils/locale'
import store from '@/store'
import apiCall from '@/utils/api'

const api = {
  getSummary: (id) => {
    return apiCall.getQuiet(`system_summary`).then(response => {
      return response.data
    })
  }
}

const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const initialState = () => {
  return {
    summary: false,
    message: '',
    requestStatus: ''
  }
}

const getters = {
  hostname: state => state.summary.hostname,
  isInline: state => state.summary.is_inline_configured,
  isLoading: state => state.requestStatus === types.LOADING,
  readonlyMode: state => state.summary.readonly_mode,
  version: state => state.summary.version
}

const actions = {
  getSummary: ({ commit, state }) => {
    if (state.summary) {
      return Promise.resolve(state.summary)
    }
    commit('SYSTEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.getSummary().then(data => {
        commit('SYSTEM_SUCCESS', data)
        if (data.readonly_mode) {
          store.dispatch('notification/danger', {
            message: i18n.t('The database is in readonly mode. Not all functionality is available.')
          })
        }
        resolve(state.summary)
      }).catch(err => {
        commit('SYSTEM_ERROR', err.response)
        reject(err)
      })
    })
  }
}

const mutations = {
  SYSTEM_REQUEST: (state) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  SYSTEM_SUCCESS: (state, data) => {
    Vue.set(state, 'summary', data)
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  SYSTEM_ERROR: (state, data) => {
    state.requestStatus = types.ERROR
    const { response: { data: { message } = {} } = {} } = data
    if (message) {
      state.message = message
    }
  },
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
