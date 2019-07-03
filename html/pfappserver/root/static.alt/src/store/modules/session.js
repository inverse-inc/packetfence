
/**
 * "session" store module
 */
import Acl from 'vue-browser-acl'
import Vue from 'vue'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'
import qs from 'qs'
import router from '@/router'
import { pfappserverCall } from '@/utils/api'
import { types } from '@/store'

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
  getTokenInfo: () => {
    return apiCall.getQuiet('token_info')
  },
  getTenants: () => {
    return apiCall.get('tenants')
  },
  getLanguage: (locale) => {
    return apiCall.get(`translation/${locale}`)
  }
}

const state = {
  loginStatus: '',
  loginPromise: null,
  loginResolver: null,
  message: '',
  token: localStorage.getItem(STORAGE_TOKEN_KEY) || '',
  username: '',
  expired: false,
  roles: [],
  tenant_id: [],
  tenants: [],
  languages: [],
  api: true,
  charts: true,
  formErrors: {}
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
  isAuthenticated: state => !!state.token && state.roles.length > 0
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
    commit('USERNAME_DELETED')
    commit('ROLES_DELETED')
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
      dispatch('delete')
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
  getTokenInfo: ({ commit }) => {
    return api.getTokenInfo().then(response => {
      commit('USERNAME_UPDATED', response.data.item.username)
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
  },
  TOKEN_DELETED: (state) => {
    state.token = ''
  },
  USERNAME_UPDATED: (state, username) => {
    state.username = username
    state.expired = false
  },
  USERNAME_DELETED: (state) => {
    state.username = ''
  },
  EXPIRED: (state) => {
    state.expired = true
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
