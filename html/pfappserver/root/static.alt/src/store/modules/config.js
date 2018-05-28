
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
  rolesList: state => {
    // Remap for b-form-select component
    return state.roles.map((item) => {
      return { value: item.id, text: `${item.id} - ${item.notes}` }
    })
  },
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
  getRoles: ({state, commit}) => {
    if (state.roles.length === 0) {
      return api.getRoles().then(response => {
        commit('ROLES_UPDATED', response.data.items)
        return state.roles
      })
    } else {
      return Promise.resolve(state.roles)
    }
  },
  getViolations: ({commit, state}) => {
    if (state.violations.length === 0) {
      return api.getViolations().then(response => {
        commit('VIOLATIONS_UPDATED', response.data.items)
        return state.violations
      })
    } else {
      return Promise.resolve(state.violations)
    }
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
