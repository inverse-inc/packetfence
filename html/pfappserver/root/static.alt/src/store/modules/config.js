
/**
 * "config" store module
 */
import apiCall from '@/utils/api'

const api = {
  getAdminRoles () {
    return apiCall({ url: 'config/admin_roles', method: 'get' })
  },
  getRoles () {
    return apiCall({ url: 'node_categories', method: 'get' })
  },
  getSources () {
    return apiCall({ url: 'config/sources', method: 'get' })
  },
  getSwitches () {
    return apiCall({ url: 'config/switches', method: 'get' })
  },
  getTenants () {
    return apiCall({ url: 'tenants', method: 'get' })
  },
  getViolations () {
    return apiCall({ url: 'config/violations', method: 'get' })
  }
}

const state = {
  adminRoles: [],
  roles: [],
  sources: [],
  switches: [],
  tenants: [],
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
  },
  groupSwitches: (switches) => {
    let ret = []
    let groups = [...new Set(switches.map(sw => sw.group))]
    groups.forEach(function (group, index, groups) {
      ret.push({ group: group, switches: switches.filter(sw => sw.group === group) })
    })
    return ret
  }
}

const getters = {
  adminRolesList: state => {
    // Remap for b-form-select component
    return state.adminRoles.map((item) => {
      return { value: item.id, name: item.id }
    })
  },
  rolesList: state => {
    // Remap for b-form-select component
    return state.roles.map((item) => {
      return { value: item.category_id, name: item.name, text: `${item.name} - ${item.notes}` }
    })
  },
  sourcesList: state => {
    // Remap for b-form-select component
    return state.sources.map((item) => {
      return { value: item.id, name: item.description }
    })
  },
  tenantsList: state => {
    // Remap for b-form-select component
    return state.tenants.map((item) => {
      return { value: item.id, name: item.name }
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
  },
  groupedSwitches: state => {
    return helpers.groupSwitches(state.switches)
  }
}

const actions = {
  getAdminRoles: ({ state, commit }) => {
    if (state.adminRoles.length === 0) {
      return api.getAdminRoles().then(response => {
        commit('ADMIN_ROLES_UPDATED', response.data.items)
        return state.adminRoles
      })
    } else {
      return Promise.resolve(state.adminRoles)
    }
  },
  getRoles: ({ state, commit }) => {
    if (state.roles.length === 0) {
      return api.getRoles().then(response => {
        commit('ROLES_UPDATED', response.data.items)
        return state.roles
      })
    } else {
      return Promise.resolve(state.roles)
    }
  },
  getSources: ({ state, commit }) => {
    if (state.sources.length === 0) {
      return api.getSources().then(response => {
        commit('SOURCES_UPDATED', response.data.items)
        return state.sources
      })
    } else {
      return Promise.resolve(state.sources)
    }
  },
  getSwitches: ({ state, commit }) => {
    if (state.switches.length === 0) {
      return api.getSwitches().then(response => {
        // group can be undefined
        response.data.items.forEach(function (item, index, items) {
          response.data.items[index] = Object.assign({ group: item.group || 'Default' }, item)
        })
        commit('SWICTHES_UPDATED', response.data.items)
        return state.switches
      })
    } else {
      return Promise.resolve(state.switches)
    }
  },
  getTenants: ({ state, commit }) => {
    if (state.tenants.length === 0) {
      return api.getTenants().then(response => {
        commit('TENANTS_UPDATED', response.data.items)
        return state.tenants
      })
    } else {
      return Promise.resolve(state.tenants)
    }
  },
  getViolations: ({ commit, state }) => {
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
  ADMIN_ROLES_UPDATED: (state, adminRoles) => {
    state.adminRoles = adminRoles
  },
  ROLES_UPDATED: (state, roles) => {
    state.roles = roles
  },
  SOURCES_UPDATED: (state, sources) => {
    state.sources = sources
  },
  SWICTHES_UPDATED: (state, switches) => {
    state.switches = switches
  },
  TENANTS_UPDATED: (state, tenants) => {
    state.tenants = tenants
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
