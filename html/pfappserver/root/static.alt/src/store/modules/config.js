
/**
 * "config" store module
 */
import apiCall from '@/utils/api'

const api = {
  getRoles () {
    return apiCall({url: 'config/roles', method: 'get'})
  },
  getViolations () {
    return apiCall({url: 'config/violations', method: 'get'})
  }
}

const state = {
  roles: [],
  violations: {}
}

const getters = {
  sortedViolations: state => {
    let sortedIds = Object.keys(state.violations).sort((a, b) => {
      if (a === 'default') {
        return a
      } else if (!state.violations[a].desc && !state.violations[b].desc) {
        return a.localeCompare(b)
      } else if (!state.violations[b].desc) {
        return a
      } else if (!state.violations[a].desc) {
        return b
      } else {
        return state.violations[a].desc.localeCompare(state.violations[b].desc)
      }
    })
    let sortedViolations = []
    for (let id of sortedIds) {
      sortedViolations.push(state.violations[id])
    }
    return sortedViolations
  }
}

const actions = {
  getRoles: ({commit, dispatch}) => {
    return api.getRoles().then(response => {
      commit('ROLES_UPDATED', response.data.items)
      return response.data.items
    })
  },
  getViolations: ({commit, dispatch}) => {
    return api.getViolations().then(response => {
      commit('VIOLATIONS_UPDATED', response.data.items)
      return response.data.items
    })
  }
}

const mutations = {
  ROLES_UPDATED: (state, roles) => {
    state.roles = roles
  },
  VIOLATIONS_UPDATED: (state, violations) => {
    let ref = {}
    for (let violation of violations) {
      ref[violation.id] = Object.assign({}, violation)
    }
    state.violations = ref
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
