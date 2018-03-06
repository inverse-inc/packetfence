import api from '../_api'

const state = {
  status: '',
  items: []
}

const getters = {
  isLoading: state => state.status === 'loading'
}

const actions = {
  search: ({state, getters, commit, dispatch}, query) => {
    return new Promise((resolve, reject) => {
      commit('SEARCH_REQUEST')
      api.search(query).then(items => {
        commit('SEARCH_SUCCESS', items)
        resolve(items)
      }).catch(err => {
        commit('SEARCH_ERROR', err.response)
        reject(err)
      })
    })
  }
}

const mutations = {
  SEARCH_REQUEST: (state) => {
    state.status = 'loading'
  },
  SEARCH_SUCCESS: (state, items) => {
    state.status = 'success'
    state.items = items
  },
  SEARCH_ERROR: (state, response) => {
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
