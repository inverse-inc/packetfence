/**
 * "session" store module
 */
import Acl from 'vue-browser-acl'
import Vue from 'vue'
import qs from 'qs'
import router from '@/router'
import { types } from '@/store'
import apiCall, { pfappserverCall } from '@/utils/api'
import i18n from '@/utils/locale'
import duration from '@/utils/duration'

const STORAGE_TOKEN_KEY = 'user-token'

const ADMIN_ROLES_ACTIONS = [
  'create',
  'create_overwrite',
  'create_multiple',
  'delete',
  'mark_as_sponsor',
  'read',
  'read_sponsored',
  'set_access_level',
  'set_access_duration',
  'set_bandwidth_balance',
  'set_role',
  'set_tenant_id',
  'set_time_balance',
  'set_unreg_date',
  'update',
  'write'
]

const api = {
  login: user => {
    return apiCall.postQuiet('login', user).then(response => {
      apiCall.defaults.headers.common['Authorization'] = `Bearer ${response.data.token}`
      // Perform login through pfappserver to obtain an HTTP cookie and therefore gain access to the previous Web admin.
      pfappserverCall.post('login', qs.stringify(user), { 'Content-Type': 'application/x-www-form-urlencoded' })
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
  }
}

const state = {
  loginStatus: '',
  loginPromise: null,
  loginResolver: null,
  message: '',
  token: localStorage.getItem(STORAGE_TOKEN_KEY) || '',
  username: '',
  expires_at: null,
  expired: false,
  roles: [],
  tenant_id: [],
  tenants: [],
  languages: [],
  api: true,
  charts: true,
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

const setupAcl = (acl) => {
  if (!Vue.$acl) Vue.$acl = acl
  for (const role of state.roles) {
    let action = ''
    let target = ''
    for (const currentAction of ADMIN_ROLES_ACTIONS) {
      if (role.toLowerCase().endsWith(currentAction)) {
        action = currentAction.replace(/_/g, '-')
        target = role.substring(0, role.length - action.length - 1).toLowerCase()
        break
      }
    }
    if (!target) {
      // eslint-disable-next-line
      console.warn(`No action found for ${role}`)
      action = 'access'
      target = role.toLowerCase()
    }
    // eslint-disable-next-line
    console.debug('configure acl ' + action + ' => ' + target)
    acl.rule(action, target, () => true)
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
  allowedNodeRolesList: state => (state.allowedNodeRoles || []).map(role => { return { value: role.category_id, name: `${role.name} - ${role.notes}`, text: `${role.name} - ${role.notes}` } }),
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
    return { value: accessLevel, name: accessLevel }
  }),
  allowedUserActions: state => state.allowedUserActions || [],
  allowedUserRoles: state => state.allowedUserRoles || [],
  allowedUserRolesList: state => (state.allowedUserRoles || []).map(role => { return { value: role.category_id, name: `${role.name} - ${role.notes}`, text: `${role.name} - ${role.notes}` } }),
  allowedUserUnregDate: state => state.allowedUserUnregDate || []
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
  update: ({ state, commit, dispatch }, token) => {
    localStorage.setItem(STORAGE_TOKEN_KEY, token)
    api.setToken(token)
    commit('TOKEN_UPDATED', token)
    return dispatch('getTokenInfo').then(roles => {
      commit('ROLES_UPDATED', roles)
      if (Vue.$acl) {
        setupAcl(Vue.$acl)
      } else {
        Vue.use(Acl, () => state.roles, setupAcl, { caseMode: false, router })
      }
    })
  },
  delete: ({ commit }) => {
    localStorage.removeItem(STORAGE_TOKEN_KEY)
    if (Vue.$acl) Vue.$acl = Vue.$acl.reset()
    commit('TOKEN_DELETED')
    commit('EXPIRES_AT_DELETED')
    commit('USERNAME_DELETED')
    commit('ROLES_DELETED')
    commit('ALLOWED_NODE_ROLES_DELETED')
    commit('ALLOWED_USER_ACCESS_DURATIONS_DELETED')
    commit('ALLOWED_USER_ACCESS_LEVELS_DELETED')
    commit('ALLOWED_USER_ACTIONS_DELETED')
    commit('ALLOWED_USER_ROLES_DELETED')
    commit('ALLOWED_USER_UNREG_DATE_DELETED')
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
        commit('LOGIN_SUCCESS', token)
        if (state.loginResolver) {
          state.loginResolver(response)
          state.loginPromise = null
        }
      })
    }).catch(err => {
      commit('LOGIN_ERROR', err.response)
      throw err
    })
  },
  logout: ({ dispatch }) => {
    return new Promise((resolve, reject) => {
      // Perform logout through pfappserver to delete the HTTP cookie
      pfappserverCall.get('logout')
      dispatch('delete')
      resolve()
    })
  },
  getTokenInfo: ({ commit }, readonly = false) => {
    return api.getTokenInfo(readonly).then(response => {
      commit('USERNAME_UPDATED', response.data.item.username)
      commit('EXPIRES_AT_UPDATED', response.data.item.expires_at)
      return response.data.item.admin_actions
    })
  },
  getTenants: ({ commit }) => {
    return api.getTenants().then(response => {
      commit('TENANTS_UPDATED', response.data)
    })
  },
  setLanguage: ({ state }, params) => {
    if (i18n.locale !== params.lang || state.languages.indexOf(params.lang) < 0) {
      if (state.languages.indexOf(params.lang) < 0) {
        return api.getLanguage(params.lang).then(response => {
          let messages = response.data.item.lexicon
          i18n.setLocaleMessage(params.lang, messages)
          state.languages.push(params.lang)
          return setI18nLanguage(params.lang)
        })
      }
      return Promise.resolve(setI18nLanguage(params.lang))
    }
    return Promise.resolve(params.lang)
  },
  getAllowedNodeRoles: ({ state, getters, commit }) => {
    if (state.allowedNodeRoles) {
      return Promise.resolve(state.allowedNodeRoles)
    }
    commit('ALLOWED_NODE_ROLES_REQUEST')
    return api.getAllowedNodeRoles().then(response => {
      commit('ALLOWED_NODE_ROLES_UPDATED', response.data.items)
      return state.allowedNodeRoles
    })
  },
  getAllowedUserAccessDurations: ({ state, getters, commit }) => {
    if (state.allowedUserAccessDurations) {
      return Promise.resolve(state.allowedUserAccessDurations)
    }
    commit('ALLOWED_USER_ACCESS_DURATIONS_REQUEST')
    return api.getAllowedUserAccessDurations().then(response => {
      commit('ALLOWED_USER_ACCESS_DURATIONS_UPDATED', response.data.items)
      return state.allowedUserAccessDurations
    })
  },
  getAllowedUserAccessLevels: ({ state, getters, commit }) => {
    if (state.allowedUserAccessLevels) {
      return Promise.resolve(state.allowedUserAccessLevels)
    }
    commit('ALLOWED_USER_ACCESS_LEVELS_REQUEST')
    return api.getAllowedUserAccessLevels().then(response => {
      commit('ALLOWED_USER_ACCESS_LEVELS_UPDATED', response.data.items)
      return state.allowedUserAccessLevels
    })
  },
  getAllowedUserActions: ({ state, getters, commit }) => {
    if (state.allowedUserActions) {
      return Promise.resolve(state.allowedUserActions)
    }
    commit('ALLOWED_USER_ACTIONS_REQUEST')
    return api.getAllowedUserActions().then(response => {
      commit('ALLOWED_USER_ACTIONS_UPDATED', response.data.items)
      return state.allowedUserActions
    })
  },
  getAllowedUserRoles: ({ state, getters, commit }) => {
    if (state.allowedUserRoles) {
      return Promise.resolve(state.allowedUserRoles)
    }
    commit('ALLOWED_USER_ROLES_REQUEST')
    return api.getAllowedUserRoles().then(response => {
      commit('ALLOWED_USER_ROLES_UPDATED', response.data.items)
      return state.allowedUserRoles
    })
  },
  getAllowedUserUnregDate: ({ state, getters, commit }) => {
    if (state.allowedUserUnregDate) {
      return Promise.resolve(state.allowedUserUnregDate)
    }
    commit('ALLOWED_USER_UNREG_DATE_REQUEST')
    return api.getAllowedUserUnregDate().then(response => {
      commit('ALLOWED_USER_UNREG_DATE_UPDATED', response.data.items)
      return state.allowedUserUnregDate
    })
  }
}

const mutations = {
  LOGIN_REQUEST: (state) => {
    state.status = types.LOADING
  },
  LOGIN_SUCCESS: (state) => {
    state.status = types.SUCCESS
  },
  LOGIN_ERROR: (state, response) => {
    state.status = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
    }
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
  ROLES_UPDATED: (state, roles) => {
    state.roles = roles
  },
  ROLES_DELETED: (state) => {
    state.roles = []
  },
  TENANTS_UPDATED: (state, data) => {
    state.tenants = data.items
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
  ALLOWED_USER_ACTIONS_DELETED: (state, data) => {
    state.allowedUserActions = false
  },
  ALLOWED_USER_ROLES_REQUEST: (state) => {
    state.allowedUserRolesStatus = types.LOADING
  },
  ALLOWED_USER_ROLES_UPDATED: (state, data) => {
    state.allowedUserRolesStatus = types.SUCCESS
    state.allowedUserRoles = data
  },
  ALLOWED_USER_ROLES_DELETED: (state, data) => {
    state.allowedUserRoles = false
  },
  ALLOWED_USER_UNREG_DATE_REQUEST: (state) => {
    state.allowedUserUnregDateStatus = types.LOADING
  },
  ALLOWED_USER_UNREG_DATE_UPDATED: (state, data) => {
    state.allowedUserUnregDateStatus = types.SUCCESS
    state.allowedUserUnregDate = data
  },
  ALLOWED_USER_UNREG_DATE_DELETED: (state, data) => {
    state.allowedUserUnregDate = false
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
  state,
  getters,
  actions,
  mutations
}
