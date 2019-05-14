import { pfappserverCall } from '@/utils/api'
import api from '../_api'

const state = {
  status: ''
}

const getters = {
  isLoading: state => state.status === 'loading'
}

const actions = {
  login: ({ commit, dispatch }, user) => {
    commit('LOGIN_REQUEST')
    return new Promise((resolve, reject) => {
      api.login(user).then(response => {
        const token = response.data.token
        dispatch('system/getSummary', null, { root: true })
        dispatch('session/update', token, { root: true }).then(() => {
          commit('LOGIN_SUCCESS', token)
          resolve(response)
        })
      }).catch(err => {
        commit('LOGIN_ERROR', err.response)
        dispatch('session/delete', null, { root: true })
        reject(err)
      })
    })
  },
  logout: ({ dispatch }) => {
    return new Promise((resolve, reject) => {
      // Perform logout through pfappserver to delete the HTTP cookie
      pfappserverCall.get('logout')
      dispatch('session/delete', null, { root: true })
      resolve()
    })
  }
}

const mutations = {
  LOGIN_REQUEST: (state) => {
    state.status = 'loading'
  },
  LOGIN_SUCCESS: (state, token) => {
    state.status = 'success'
  },
  LOGIN_ERROR: (state, response) => {
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
