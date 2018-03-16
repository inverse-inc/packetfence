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
    let apiPromise = Object.keys(query).length ? api.search({ query }) : api.all()
    return new Promise((resolve, reject) => {
      commit('SEARCH_REQUEST')
      apiPromise.then(items => {
        commit('SEARCH_SUCCESS', items)
        resolve(items)
      }).catch(err => {
        commit('SEARCH_ERROR', err.response)
        reject(err)
      })
    })
  },
  getUser: ({dispatch}, pid) => {
    return api.user(pid)
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
