/**
* "$_pftest" store module
*/
import api from './_api'

const state = () => ({
  status: '',
  message: '',
  subcmd: 'authentication',
  results: []
})

const getters = {
  isLoading: state => state.status === 'loading',
  results: state => state.results,
  message: state => state.message,
  subcmd: state => state.subcmd
}

const actions = {
  setSubcmd: ({ commit }, subcmd) => commit('SET_SUBCMD', subcmd),
  runAuthentication: ({ commit }, body) => {
    commit('REQUEST')
    return api.runAuthentication(body).then(response => {
      commit('SUCCESS', response)
      return response
    }).catch(err => {
      commit('ERROR', err && err.response)
      throw err
    })
  },
  runProfileFilter: ({ commit }, body) => {
    commit('REQUEST')
    return api.runProfileFilter(body).then(response => {
      commit('SUCCESS', response)
      return response
    }).catch(err => {
      commit('ERROR', err && err.response)
      throw err
    })
  }
}

const mutations = {
  SET_SUBCMD: (state, subcmd) => { state.subcmd = subcmd; state.results = [] },
  REQUEST: state => { state.status = 'loading'; state.message = '' },
  SUCCESS: (state, response) => {
    state.status = 'success'
    state.results = (response && response.items) || []
  },
  ERROR: (state, response) => {
    state.status = 'error'
    state.results = []
    if (response && response.data) state.message = response.data.message
  }
}

export default { namespaced: true, state, getters, actions, mutations }
