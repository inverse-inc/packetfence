/**
* "$_fingerbank_communication" store module
*/
import api from '@/views/Nodes/_api'

// Default values
const state = () => {
  return {
    cache: {}, // communcation details
    message: '',
    status: ''
  }
}

const getters = {
  isLoading: state => state.status === 'loading',
}

const actions = {
  get: ({ commit }, params) => {
    return new Promise((resolve, reject) => {
      commit('REQUEST')
      api.fingerbankCommunications(params).then(response => {
        commit('RESPONSE', response)
        resolve(true)
      }).catch(err => {
        commit('ERROR', err)
        reject(err)
      })
    })
  },
}

const mutations = {
  REQUEST: (state) => {
    state.status = 'loading'
    state.message = ''
  },
  RESPONSE: (state, response) => {
    state.status = 'success'
    state.cache = {
//      ...state.cache,
      ...response
    }
  },
  ERROR: (state, response) => {
    state.status = 'error'
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
