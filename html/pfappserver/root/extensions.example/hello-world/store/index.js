/**
 * Global "helloWorld" store module
 */
import { types } from '@/store'
import api from '../api'

const initialState = () => ({
  hostname: null,
  status: ''
})

const getters = {
  isLoading: state => state.status === types.LOADING
}

const actions = {
  getHostname: ({ commit }) => {
    commit('HOSTNAME_REQUEST')
    return api.hostname().then(hostname => {
      commit('HOSTNAME_SUCCESS', hostname)
      return hostname
    }).catch(err => {
      commit('HOSTNAME_ERROR')
      throw err
    })
  }
}

const mutations = {
  HOSTNAME_REQUEST: state => {
    state.status = types.LOADING
  },
  HOSTNAME_SUCCESS: (state, hostname) => {
    state.status = types.SUCCESS
    state.hostname = hostname
  },
  HOSTNAME_ERROR: state => {
    state.status = types.ERROR
  },
  $RESET: state => {
    Object.assign(state, initialState())
  }
}

export default {
  namespaced: true,
  state: initialState,
  getters,
  actions,
  mutations
}
