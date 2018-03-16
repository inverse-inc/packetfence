
/**
 * "config" store module
 */
import apiCall from '@/utils/api'

const api = {
  getRoles: () => {
    return apiCall({url: 'config/roles', method: 'get'})
  }
}

const state = {
  roles: []
}

const getters = {
}

const actions = {
  getRoles: ({commit, dispatch}) => {
    return api.getRoles().then(response => {
      commit('ROLES_UPDATED', response.data.items)
      return response.data.items
    })
  }
}

const mutations = {
  ROLES_UPDATED: (state, roles) => {
    state.roles = roles
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
