/**
 * "session" store module
 */
import { types } from '@/store'
import acl, { setupAcl } from '@/utils/acl'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'
import duration from '@/utils/duration'

const STORAGE_TOKEN_KEY = 'user-token'
const STORAGE_TENANT_ID = 'X-PacketFence-Tenant-Id'

const api = {
  login: user => {
    return apiCall.postQuiet('login', user).then(response => {
      apiCall.defaults.headers.common['Authorization'] = `Bearer ${response.data.token}`
      return response
    })
  },
  setToken: (token) => {
    apiCall.defaults.headers.common['Authorization'] = `Bearer ${token}`
  },
  getTokenInfo: (readonly) => {
    let url = 'token_info'
    if (readonly) url += '?no-expiration-extension=1'
    return apiCall.getQuiet(url)
  },
  getTenants: () => {
    return apiCall.get('tenants')
  },
  getLanguage: (locale) => {
    return apiCall.get(`translation/${locale}`)
  },
  getAllowedNodeRoles: () => {
    return apiCall.get(`current_user/allowed_node_roles`)
  },
  getAllowedUserAccessDurations: () => {
    return apiCall.get(`current_user/allowed_user_access_durations`)
  },
  getAllowedUserAccessLevels: () => {
    return apiCall.get(`current_user/allowed_user_access_levels`)
  },
  getAllowedUserActions: () => {
    return apiCall.get(`current_user/allowed_user_actions`)
  },
  getAllowedUserRoles: () => {
    return apiCall.get(`current_user/allowed_user_roles`)
  },
  getAllowedUserUnregDate: () => {
    return apiCall.get(`current_user/allowed_user_unreg_date`)
  },
  getAdvanced: () => {
    return apiCall.getQuiet('config/base/advanced').then(response => {
      return response.data.item
    })
  }
}

const initialState = () => {
  return {
    loginStatus: '',
    loginPromise: null,
    loginResolver: null,
    configuratorEnabled: false,
    configuratorActive: false,
    message: '',
    token: localStorage.getItem(STORAGE_TOKEN_KEY) || '',
    username: '',
    expires_at: null,
    expired: false,
    roles: [],
    tenant: null,
    tenant_id_mask: localStorage.getItem(STORAGE_TENANT_ID) || null,
    tenants: [],
    languages: [],
    api: undefined,
    charts: undefined,
    formErrors: {},
    isLoadingAllowedNodeRoles: false,
    isLoadingAllowedUserAccessDurations: false,
    isLoadingAllowedUserAccessLevels: false,
    isLoadingAllowedUserActions: false,
    isLoadingAllowedUserRoles: false,
    isLoadingAllowedUserUnregDate: false,
    allowedNodeRoles: false,
    allowedNodeRolesStatus: '',
    allowedUserAccessDurations: false,
    allowedUserAccessDurationsStatus: '',
    allowedUserAccessLevels: false,
    allowedUserAccessLevelsStatus: '',
    allowedUserActions: false,
    allowedUserActionsStatus: '',
    allowedUserRoles: false,
    allowedUserRolesStatus: '',
    allowedUserUnregDate: false,
    allowedUserUnregDateStatus: ''
  }
}

const getters = {
  isLoading: state => state.loginStatus === types.LOADING,
  isAuthenticated: state => !!state.token && state.roles.length > 0,
  getSessionTime: state => () => {
    if (state.expires_at) {
      const now = new Date()
      if (now >= state.expires_at) {
        return false
      }
      return (state.expires_at - now)
    }
    return false
  },
  isLoadingAllowedNodeRoles: state => state.isLoadingAllowedNodeRolesStatus === types.LOADING,
  isLoadingAllowedUserAccessDurations: state => state.isLoadingAllowedUserAccessDurationsStatus === types.LOADING,
  isLoadingAllowedUserAccessLevels: state => state.isLoadingAllowedUserAccessDurationsStatus === types.LOADING,
  isLoadingAllowedUserActions: state => state.isLoadingAllowedUserActionsStatus === types.LOADING,
  isLoadingAllowedUserRoles: state => state.isLoadingAllowedUserRolesStatus === types.LOADING,
  isLoadingAllowedUserUnregDate: state => state.isLoadingAllowedUserUnregDateStatus === types.LOADING,
  allowedNodeRoles: state => state.allowedNodeRoles || [],
  allowedNodeRolesList: state => (state.allowedNodeRoles || []).map(role => { return { value: role.category_id, text: `${role.name} - ${role.notes}` } }),
  allowedUserAccessDurations: state => state.allowedUserAccessDurations || [],
  allowedUserAccessDurationsList: state => (state.allowedUserAccessDurations || []).map(_accessDuration => {
    const { access_duration: accessDuration } = _accessDuration
    return duration.deserialize(accessDuration) // deserialize
  }).filter(
    accessDuration => accessDuration // strip invalid
  ).sort((a, b) => {
    return (a.sort > b.sort) ? 1 : -1
  }),
  allowedUserAccessLevels: state => state.allowedUserAccessLevels || [],
  allowedUserAccessLevelsList: state => (state.allowedUserAccessLevels || []).map(_accessLevel => {
    const { access_level: accessLevel } = _accessLevel
    return { value: accessLevel, text: accessLevel }
  }),
  allowedUserActions: state => state.allowedUserActions || [],
  allowedUserRoles: state => state.allowedUserRoles || [],
  allowedUserRolesList: state => (state.allowedUserRoles || []).map(role => { return { value: role.category_id, text: `${role.name} - ${role.notes}` } }),
  allowedUserUnregDate: state => state.allowedUserUnregDate || [],
  tenantIdMask: state => state.tenant_id_mask || state.tenant.id,
  tenantMask: (state) => {
    if (state.tenant_id_mask) {
      return state.tenants.find(t => t.id === state.tenant_id_mask)
    }
    return state.tenant
  },
  aclContext: state => {
    if (state.roles.includes('TENANT_MASTER')) { // is tenant master
      if (!state.tenant_id_mask) { // tenant is not masked
        return state.roles // return all roles
      }
    }
    // mask TENANT_MASTER, CONFIGURATION_MAIN and SERVICES roles
    return state.roles.filter(role => {
      switch (true) {
        case role === 'TENANT_MASTER':
        case new RegExp("^CONFIGURATION_MAIN").test(role):
        case new RegExp("^SERVICES").test(role):
          return false // prohibit ACL
      }
      return role
    })
  },
  configuratorEnabled: state => state.configuratorEnabled
}

const actions = {
  load: ({ state, dispatch }) => {
    if (state.token) {
      if (!state.username) {
        return dispatch('update', state.token)
      }
      return Promise.resolve()
    } else {
      return Promise.reject(new Error('No token'))
    }
  },
  update: ({ commit, dispatch }, token) => {
    localStorage.setItem(STORAGE_TOKEN_KEY, token)
    api.setToken(token)
    commit('TOKEN_UPDATED', token)
    return dispatch('getTokenInfo').then(roles => {
      commit('ROLES_UPDATED', roles)
      setupAcl()
      dispatch('getConfiguratorState')
      dispatch('getTenants')
    })
  },
  delete: ({ commit }) => {
    localStorage.removeItem(STORAGE_TOKEN_KEY)
    localStorage.removeItem(STORAGE_TENANT_ID)
    acl.reset()
    commit('TOKEN_DELETED')
    commit('EXPIRES_AT_DELETED')
    commit('TENANT_DELETED')
    commit('TENANT_ID_MASK_DELETED')
    commit('TENANTS_DELETED')
    commit('USERNAME_DELETED')
    commit('ROLES_DELETED')
    commit('ALLOWED_NODE_ROLES_DELETED')
    commit('ALLOWED_USER_ACCESS_DURATIONS_DELETED')
    commit('ALLOWED_USER_ACCESS_LEVELS_DELETED')
    commit('ALLOWED_USER_ACTIONS_DELETED')
    commit('ALLOWED_USER_ROLES_DELETED')
    commit('ALLOWED_USER_UNREG_DATE_DELETED')
    commit('CONFIGURATOR_DISABLED')
  },
  resolveLogin: ({ state }) => {
    if (state.loginPromise === null) {
      state.loginPromise = new Promise(resolve => {
        state.loginResolver = resolve
      })
    }
    return state.loginPromise
  },
  login: ({ state, commit, dispatch }, user) => {
    commit('LOGIN_REQUEST')
    return api.login(user).then(response => {
      const token = response.data.token
      return dispatch('update', token).then(() => {
        const hasAccess = ['reports', 'services', 'radius_log', 'dhcp_option_82', 'dns_log', 'admin_api_audit_log', 'nodes', 'users', 'configuration_main'].find(target => {
          return acl.$can('read', target)
        })
        if (hasAccess) {
          commit('LOGIN_SUCCESS', token)
          if (state.loginResolver) {
            state.loginResolver(response)
            state.loginPromise = null
          }
        } else {
          const err = { response: { data: { message: i18n.t(`You don't have enough privileges to login`) } } }
          dispatch('delete')
          commit('LOGIN_ERROR', err.response)
          throw err
        }
      })
    }).catch(err => {
      commit('LOGIN_ERROR', err.response)
      throw err
    })
  },
  logout: ({ dispatch }) => {
    return new Promise((resolve) => {
      dispatch('delete')
      resolve()
    })
  },
  getTokenInfo: ({ commit }, readonly = false) => {
    return api.getTokenInfo(readonly).then(response => {
      commit('USERNAME_UPDATED', response.data.item.username)
      commit('EXPIRES_AT_UPDATED', response.data.item.expires_at)
      commit('TENANT_UPDATED', response.data.item.tenant)
      return response.data.item.admin_actions // return ACLs
    })
  },
  getTenants: ({ commit }) => {
    if (acl.$can('read', 'system')) {
      return api.getTenants().then(response => {
        commit('TENANTS_UPDATED', response.data)
      })
    } else {
      return Promise.resolve()
    }
  },
  setLanguage: ({ state, commit }, params) => {
    if (i18n.locale !== params.lang || state.languages.indexOf(params.lang) < 0) {
      if (state.languages.indexOf(params.lang) < 0) {
        return api.getLanguage(params.lang).then(response => {
          let messages = response.data.item.lexicon
          i18n.setLocaleMessage(params.lang, messages)
          commit('LANGUAGES_UPDATED', [ ...state.languages, params.lang ])
          return setI18nLanguage(params.lang)
        })
      }
      return Promise.resolve(setI18nLanguage(params.lang))
    }
    return Promise.resolve(params.lang)
  },
  getAllowedNodeRoles: ({ state, commit }) => {
    if (state.allowedNodeRoles) {
      return Promise.resolve(state.allowedNodeRoles)
    }
    commit('ALLOWED_NODE_ROLES_REQUEST')
    return api.getAllowedNodeRoles().then(response => {
      commit('ALLOWED_NODE_ROLES_UPDATED', response.data.items)
      return state.allowedNodeRoles
    })
  },
  getAllowedUserAccessDurations: ({ state, commit }) => {
    if (state.allowedUserAccessDurations) {
      return Promise.resolve(state.allowedUserAccessDurations)
    }
    commit('ALLOWED_USER_ACCESS_DURATIONS_REQUEST')
    return api.getAllowedUserAccessDurations().then(response => {
      commit('ALLOWED_USER_ACCESS_DURATIONS_UPDATED', response.data.items)
      return state.allowedUserAccessDurations
    })
  },
  getAllowedUserAccessLevels: ({ state, commit }) => {
    if (state.allowedUserAccessLevels) {
      return Promise.resolve(state.allowedUserAccessLevels)
    }
    commit('ALLOWED_USER_ACCESS_LEVELS_REQUEST')
    return api.getAllowedUserAccessLevels().then(response => {
      commit('ALLOWED_USER_ACCESS_LEVELS_UPDATED', response.data.items)
      return state.allowedUserAccessLevels
    })
  },
  getAllowedUserActions: ({ state, commit }) => {
    if (state.allowedUserActions) {
      return Promise.resolve(state.allowedUserActions)
    }
    commit('ALLOWED_USER_ACTIONS_REQUEST')
    return api.getAllowedUserActions().then(response => {
      commit('ALLOWED_USER_ACTIONS_UPDATED', response.data.items)
      return state.allowedUserActions
    })
  },
  getAllowedUserRoles: ({ state, commit }) => {
    if (state.allowedUserRoles) {
      return Promise.resolve(state.allowedUserRoles)
    }
    commit('ALLOWED_USER_ROLES_REQUEST')
    return api.getAllowedUserRoles().then(response => {
      commit('ALLOWED_USER_ROLES_UPDATED', response.data.items)
      return state.allowedUserRoles
    })
  },
  getAllowedUserUnregDate: ({ state, commit }) => {
    if (state.allowedUserUnregDate) {
      return Promise.resolve(state.allowedUserUnregDate)
    }
    commit('ALLOWED_USER_UNREG_DATE_REQUEST')
    return api.getAllowedUserUnregDate().then(response => {
      commit('ALLOWED_USER_UNREG_DATE_UPDATED', response.data.items)
      return state.allowedUserUnregDate
    })
  },
  getConfiguratorState: ({ commit }) => {
    if (acl.$can('read', 'configuration_main')) {
      return api.getAdvanced().then(advanced => {
        const enabled = advanced.configurator === 'enabled'
        if (enabled) {
          commit('CONFIGURATOR_ENABLED')
        } else {
          commit('CONFIGURATOR_DISABLED')
        }
        return enabled
      }).catch(() => {
        // noop
      })
    } else {
      return Promise.resolve()
    }
  },
  updateConfiguratorState: ({ commit }, state) => {
    if (state === 'enabled') {
      commit('CONFIGURATOR_ENABLED')
    } else {
      commit('CONFIGURATOR_DISABLED')
    }
  },
  setTenantIdMask: ({ state, commit }, tenantId = 0) => {
    if (tenantId !== state.tenant_id_mask) {
      if (state.tenant.id === 0) { // is multi-tenant, can mutate
        if (!+tenantId) {
          commit('TENANT_ID_MASK_DELETED')
        }
        else if (+tenantId !== state.tenant_id_mask) {
          commit('TENANT_ID_MASK_UPDATED', tenantId)
        }
      }
      acl.reset()
      setupAcl()
    }
  }
}

const mutations = {
  LOGIN_REQUEST: (state) => {
    state.loginStatus = types.LOADING
  },
  LOGIN_SUCCESS: (state) => {
    state.loginStatus = types.SUCCESS
  },
  LOGIN_ERROR: (state, response) => {
    state.loginStatus = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  CONFIGURATOR_ENABLED: (state) => {
    state.configuratorEnabled = true
  },
  CONFIGURATOR_DISABLED: (state) => {
    state.configuratorEnabled = false
  },
  CONFIGURATOR_ACTIVE: (state) => {
    state.configuratorActive = true
  },
  CONFIGURATOR_INACTIVE: (state) => {
    state.configuratorActive = false
  },
  TOKEN_UPDATED: (state, token) => {
    state.token = token
    state.expired = false
  },
  TOKEN_DELETED: (state) => {
    state.token = ''
    state.expired = false
  },
  USERNAME_UPDATED: (state, username) => {
    state.username = username
  },
  USERNAME_DELETED: (state) => {
    state.username = ''
  },
  EXPIRED: (state) => {
    state.expired = true
    state.expires_at = null
  },
  EXPIRES_AT_UPDATED: (state, expiresAt) => {
    state.expires_at = new Date(expiresAt)
  },
  EXPIRES_AT_DELETED: (state) => {
    state.expires_at = null
  },
  TENANT_UPDATED: (state, tenant) => {
    state.tenant = tenant
  },
  TENANT_DELETED: (state) => {
    state.tenant = null
  },
  TENANT_ID_MASK_UPDATED: (state, tenantId) => {
    state.tenant_id_mask = tenantId
    localStorage.setItem(STORAGE_TENANT_ID, +tenantId)
  },
  TENANT_ID_MASK_DELETED: (state) => {
    state.tenant_id_mask = null
    localStorage.removeItem(STORAGE_TENANT_ID)
  },
  TENANTS_UPDATED: (state, data) => {
    state.tenants = data.items
  },
  TENANTS_DELETED: (state) => {
    state.tenants = []
  },
  ROLES_UPDATED: (state, roles) => {
    state.roles = roles
  },
  ROLES_DELETED: (state) => {
    state.roles = []
  },
  API_OK: (state) => {
    state.api = true
  },
  API_ERROR: (state) => {
    state.api = false
  },
  CHARTS_OK: (state) => {
    state.charts = true
  },
  CHARTS_ERROR: (state) => {
    state.charts = false
  },
  FORM_OK: (state) => {
    state.formErrors = {}
  },
  FORM_ERROR: (state, data) => {
    state.formErrors = data
  },
  ALLOWED_NODE_ROLES_REQUEST: (state) => {
    state.allowedNodeRolesStatus = types.LOADING
  },
  ALLOWED_NODE_ROLES_UPDATED: (state, data) => {
    state.allowedNodeRolesStatus = types.SUCCESS
    state.allowedNodeRoles = data
  },
  ALLOWED_NODE_ROLES_DELETED: (state) => {
    state.allowedNodeRoles = false
  },
  ALLOWED_USER_ACCESS_DURATIONS_REQUEST: (state) => {
    state.allowedUserAccessDurationsStatus = types.LOADING
  },
  ALLOWED_USER_ACCESS_DURATIONS_UPDATED: (state, data) => {
    state.allowedUserAccessDurationsStatus = types.SUCCESS
    state.allowedUserAccessDurations = data
  },
  ALLOWED_USER_ACCESS_DURATIONS_DELETED: (state) => {
    state.allowedUserAccessDurations = false
  },
  ALLOWED_USER_ACCESS_LEVELS_REQUEST: (state) => {
    state.allowedUserAccessLevelsStatus = types.LOADING
  },
  ALLOWED_USER_ACCESS_LEVELS_UPDATED: (state, data) => {
    state.allowedUserAccessLevelsStatus = types.SUCCESS
    state.allowedUserAccessLevels = data
  },
  ALLOWED_USER_ACCESS_LEVELS_DELETED: (state) => {
    state.allowedUserAccessLevels = false
  },
  ALLOWED_USER_ACTIONS_REQUEST: (state) => {
    state.allowedUserActionsStatus = types.LOADING
  },
  ALLOWED_USER_ACTIONS_UPDATED: (state, data) => {
    state.allowedUserActionsStatus = types.SUCCESS
    state.allowedUserActions = data
  },
  ALLOWED_USER_ACTIONS_DELETED: (state) => {
    state.allowedUserActions = false
  },
  ALLOWED_USER_ROLES_REQUEST: (state) => {
    state.allowedUserRolesStatus = types.LOADING
  },
  ALLOWED_USER_ROLES_UPDATED: (state, data) => {
    state.allowedUserRolesStatus = types.SUCCESS
    state.allowedUserRoles = data
  },
  ALLOWED_USER_ROLES_DELETED: (state) => {
    state.allowedUserRoles = false
  },
  ALLOWED_USER_UNREG_DATE_REQUEST: (state) => {
    state.allowedUserUnregDateStatus = types.LOADING
  },
  ALLOWED_USER_UNREG_DATE_UPDATED: (state, data) => {
    state.allowedUserUnregDateStatus = types.SUCCESS
    state.allowedUserUnregDate = data
  },
  ALLOWED_USER_UNREG_DATE_DELETED: (state) => {
    state.allowedUserUnregDate = false
  },
  LANGUAGES_UPDATED: (state, languages) => {
    state.languages = languages
  },
  // eslint-disable-next-line no-unused-vars
  $RESET: (state) => {
    // noop
  }
}

function setI18nLanguage (lang) {
  i18n.locale = lang
  apiCall.defaults.headers.common['Accept-Language'] = lang
  document.querySelector('html').setAttribute('lang', lang)
  return lang
}

export default {
  namespaced: true,
  state: initialState(),
  getters,
  actions,
  mutations
}
