
/**
 * "config" store module
 */
import apiCall from '@/utils/api'

const api = {
  getRoles () {
    return apiCall({url: 'node_categories', method: 'get'})
  },
  getViolations () {
    return apiCall({url: 'config/violations', method: 'get'})
  }
}

const state = {
  roles: [],
  violations: {}
}

const helpers = {
  sortViolations: (violations) => {
    let sortedIds = Object.keys(violations).sort((a, b) => {
      if (a === 'defaults') {
        return a
      } else if (!violations[a].desc && !violations[b].desc) {
        return a.localeCompare(b)
      } else if (!violations[b].desc) {
        return a
      } else if (!violations[a].desc) {
        return b
      } else {
        return violations[a].desc.localeCompare(violations[b].desc)
      }
    })
    let sortedViolations = []
    for (let id of sortedIds) {
      sortedViolations.push(violations[id])
    }
    return sortedViolations
  }
}

const getters = {
  rolesList: state => {
    // Remap for b-form-select component
    return state.roles.map((item) => {
      return { value: item.category_id, text: `${item.name} - ${item.notes}` }
    })
  },
  violationsList: state => {
    // Remap for b-form-select component
    return helpers.sortViolations(state.violations).filter(violation => violation.enabled === 'Y').map((item) => {
      return { value: item.id, text: item.desc }
    })
  },
  sortedViolations: state => {
    return helpers.sortViolations(state.violations)
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
    if (Object.keys(state.violations).length === 0) {
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
