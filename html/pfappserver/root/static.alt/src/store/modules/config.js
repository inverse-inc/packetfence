
/**
 * "config" store module
 */
import apiCall from '@/utils/api'

const api = {
  getAdminRoles () {
    return apiCall({ url: 'config/admin_roles', method: 'get' })
  },
  getBillingTiers () {
    return apiCall({ url: 'config/billing_tiers', method: 'get' })
  },
  getDomains () {
    return apiCall({ url: 'config/domains', method: 'get' })
  },
  getFloatingDevices () {
    return apiCall({ url: 'config/floating_devices', method: 'get' })
  },
  getRealms () {
    return apiCall({ url: 'config/realms', method: 'get' })
  },
  getRoles () {
    return apiCall({ url: 'node_categories', method: 'get', params: { limit: 1000 } })
  },
  getSources () {
    return apiCall({ url: 'config/sources', method: 'get' })
  },
  getSwitches () {
    return apiCall({ url: 'config/switches', method: 'get' })
  },
  getSwitchGroups () {
    return apiCall({ url: 'config/switch_groups', method: 'get' })
  },
  getTenants () {
    return apiCall({ url: 'tenants', method: 'get' })
  },
  getViolations () {
    return apiCall({ url: 'config/violations', method: 'get' })
  }
}

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

const state = { // set intitial states to `false` (not `[]` or `{}`) to avoid infinite loop when response is empty.
  adminRolesStatus: '',
  adminRoles: false,
  billingTiersStatus: '',
  billingTiers: false,
  domainsStatus: '',
  domains: false,
  floatingDevicesStatus: '',
  floatingDevices: false,
  realmsStatus: '',
  realms: false,
  rolesStatus: '',
  roles: false,
  sourcesStatus: '',
  sources: false,
  switchesStatus: '',
  switches: false,
  switchGroupsStatus: '',
  switchGroups: false,
  tenantsStatus: '',
  tenants: false,
  violationsStatus: '',
  violations: false
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
  isLoadingAdminRoles: state => {
    return state.adminRolesStatus === types.LOADING
  },
  isLoadingBillingTiers: state => {
    return state.billingTiersStatus === types.LOADING
  },
  isLoadingDomains: state => {
    return state.domainsStatus === types.LOADING
  },
  isLoadingFloatingDevices: state => {
    return state.floatingDevicesStatus === types.LOADING
  },
  isLoadingRealms: state => {
    return state.realmsStatus === types.LOADING
  },
  isLoadingRoles: state => {
    return state.rolesStatus === types.LOADING
  },
  isLoadingSources: state => {
    return state.sourcesStatus === types.LOADING
  },
  isLoadingSwitches: state => {
    return state.switchesStatus === types.LOADING
  },
  isLoadingSwitchGroups: state => {
    return state.switchGroupsStatus === types.LOADING
  },
  isLoadingTenants: state => {
    return state.tenantsStatus === types.LOADING
  },
  isLoadingViolations: state => {
    return state.violationsStatus === types.LOADING
  },
  adminRolesList: state => {
    // Remap for b-form-select component
    if (!state.adminRoles) return []
    return state.adminRoles.map((item) => {
      return { value: item.id, name: item.id }
    })
  },
  realmsList: state => {
    // Remap for b-form-select component
    if (!state.realms) return []
    return state.realms.map((item) => {
      return { value: item.id, name: item.id }
    })
  },
  rolesList: state => {
    // Remap for b-form-select component
    if (!state.roles) return []
    return state.roles.map((item) => {
      return { value: item.category_id, name: item.name, text: `${item.name} - ${item.notes}` }
    })
  },
  sourcesList: state => {
    // Remap for b-form-select component
    if (!state.sources) return []
    return state.sources.map((item) => {
      return { value: item.id, name: item.description }
    })
  },
  tenantsList: state => {
    // Remap for b-form-select component
    if (!state.tenants) return []
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
    if (getters.isLoadingAdminRoles) {
      return
    }
    if (!state.adminRoles) {
      return api.getAdminRoles().then(response => {
        commit('ADMIN_ROLES_UPDATED', response.data.items)
        return state.adminRoles
      })
    } else {
      return Promise.resolve(state.adminRoles)
    }
  },
  getBillingTiers: ({ state, getters, commit }) => {
    if (getters.isLoadingBillingTiers) {
      return
    }
    if (!state.billingTiers) {
      commit('BILLING_TIERS_REQUEST')
      return api.getBillingTiers().then(response => {
        commit('BILLING_TIERS_UPDATED', response.data.items)
        return state.billingTiers
      })
    } else {
      return Promise.resolve(state.billingTiers)
    }
  },
  getDomains: ({ state, getters, commit }) => {
    if (getters.isLoadingDomains) {
      return
    }
    if (!state.domains) {
      commit('DOMAINS_REQUEST')
      return api.getDomains().then(response => {
        commit('DOMAINS_UPDATED', response.data.items)
        return state.domains
      })
    } else {
      return Promise.resolve(state.domains)
    }
  },
  getFloatingDevices: ({ state, getters, commit }) => {
    if (getters.isLoadingFloatingDevices) {
      return
    }
    if (!state.floatingDevices) {
      commit('FLOATING_DEVICES_REQUEST')
      return api.getFloatingDevices().then(response => {
        commit('FLOATING_DEVICES_UPDATED', response.data.items)
        return state.floatingDevices
      })
    } else {
      return Promise.resolve(state.floatingDevices)
    }
  },
  getRealms: ({ state, getters, commit }) => {
    if (getters.isLoadingRealms) {
      return
    }
    if (!state.realms) {
      commit('REALMS_REQUEST')
      return api.getRealms().then(response => {
        commit('REALMS_UPDATED', response.data.items)
        return state.realms
      })
    } else {
      return Promise.resolve(state.realms)
    }
  },
  getRoles: ({ state, getters, commit }) => {
    if (getters.isLoadingRoles) {
      return
    }
    if (!state.roles) {
      commit('ROLES_REQUEST')
      return api.getRoles().then(response => {
        commit('ROLES_UPDATED', response.data.items)
        return state.roles
      })
    } else {
      return Promise.resolve(state.roles)
    }
  },
  getSources: ({ state, commit }) => {
    if (getters.isLoadingSources) {
      return
    }
    if (!state.sources) {
      commit('SOURCES_REQUEST')
      return api.getSources().then(response => {
        commit('SOURCES_UPDATED', response.data.items)
        return state.sources
      })
    } else {
      return Promise.resolve(state.sources)
    }
  },
  getSwitches: ({ state, commit }) => {
    if (getters.isLoadingSwitches) {
      return
    }
    if (!state.switches) {
      commit('SWICTHES_REQUEST')
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
  getSwitchGroups: ({ state, commit }) => {
    if (getters.isLoadingSwitchGroups) {
      return
    }
    if (!state.switchGroups) {
      commit('SWICTH_GROUPS_REQUEST')
      return api.getSwitchGroups().then(response => {
        commit('SWICTH_GROUPS_UPDATED', response.data.items)
        return state.switchGroups
      })
    } else {
      return Promise.resolve(state.switchGroups)
    }
  },
  getTenants: ({ state, commit }) => {
    if (getters.isLoadingTenants) {
      return
    }
    if (!state.tenants) {
      commit('TENANTS_REQUEST')
      return api.getTenants().then(response => {
        commit('TENANTS_UPDATED', response.data.items)
        return state.tenants
      })
    } else {
      return Promise.resolve(state.tenants)
    }
  },
  getViolations: ({ commit, state }) => {
    if (getters.isLoadingViolations) {
      return
    }
    if (!state.violations) {
      commit('VIOLATIONS_REQUEST')
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
  ADMIN_ROLES_REQUEST: (state) => {
    state.adminRolesStatus = types.LOADING
  },
  ADMIN_ROLES_UPDATED: (state, adminRoles) => {
    state.adminRoles = adminRoles
    state.adminRolesStatus = types.SUCCESS
  },
  BILLING_TIERS_REQUEST: (state) => {
    state.billingTiersStatus = types.LOADING
  },
  BILLING_TIERS_UPDATED: (state, billingTiers) => {
    state.billingTiers = billingTiers
    state.billingTiersStatus = types.SUCCESS
  },
  DOMAINS_REQUEST: (state) => {
    state.domainsStatus = types.LOADING
  },
  DOMAINS_UPDATED: (state, domains) => {
    state.domains = domains
    state.domainsStatus = types.SUCCESS
  },
  FLOATING_DEVICES_REQUEST: (state) => {
    state.floatingDevicesStatus = types.LOADING
  },
  FLOATING_DEVICES_UPDATED: (state, floatingDevices) => {
    state.floatingDevices = floatingDevices
    state.floatingDevicesStatus = types.SUCCESS
  },
  REALMS_REQUEST: (state) => {
    state.realmsStatus = types.LOADING
  },
  REALMS_UPDATED: (state, realms) => {
    state.realms = realms
    state.realmsStatus = types.SUCCESS
  },
  ROLES_REQUEST: (state) => {
    state.rolesStatus = types.LOADING
  },
  ROLES_UPDATED: (state, roles) => {
    state.roles = roles
    state.rolesStatus = types.SUCCESS
  },
  SOURCES_REQUEST: (state) => {
    state.sourcesStatus = types.LOADING
  },
  SOURCES_UPDATED: (state, sources) => {
    state.sources = sources
    state.sourcesStatus = types.SUCCESS
  },
  SWICTHES_REQUEST: (state) => {
    state.switchesStatus = types.LOADING
  },
  SWICTHES_UPDATED: (state, switches) => {
    state.switches = switches
    state.switchesStatus = types.SUCCESS
  },
  SWICTH_GROUPS_REQUEST: (state) => {
    state.switchGroupsStatus = types.LOADING
  },
  SWICTH_GROUPS_UPDATED: (state, switchGroups) => {
    state.switchGroups = switchGroups
    state.switchGroupsStatus = types.SUCCESS
  },
  TENANTS_REQUEST: (state) => {
    state.tenantsStatus = types.LOADING
  },
  TENANTS_UPDATED: (state, tenants) => {
    state.tenants = tenants
    state.tenantsStatus = types.SUCCESS
  },
  VIOLATIONS_REQUEST: (state) => {
    state.violationsStatus = types.LOADING
  },
  VIOLATIONS_UPDATED: (state, violations) => {
    let ref = {}
    for (let violation of violations) {
      ref[violation.id] = Object.assign({}, violation)
    }
    state.violations = ref
    state.violationsStatus = types.SUCCESS
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
