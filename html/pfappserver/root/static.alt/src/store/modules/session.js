
/**
 * "session" store module
 */
import Vue from 'vue'
import Acl from 'vue-browser-acl'
import router from '@/router'
import apiCall from '@/utils/api'

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
  setToken: (token) => {
    apiCall.defaults.headers.common['Authorization'] = `Bearer ${token}`
  },
  getTokenInfo: () => {
    return apiCall.get('token_info')
  },
  getTenants: () => {
    return apiCall.get('tenants')
  },
  getLanguage: (locale) => {
    return apiCall.get(`translation/${locale}`)
  }
}

const state = {
  token: localStorage.getItem(STORAGE_TOKEN_KEY) || '',
  username: '',
  roles: [],
  tenant_id: [],
  tenants: [],
  languages: [],
  api: true,
  charts: true,
  formErrors: {}
}

const getters = {
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
  update: ({ commit, dispatch }, token) => {
    localStorage.setItem(STORAGE_TOKEN_KEY, token)
    api.setToken(token)
    commit('TOKEN_UPDATED', token)
    return dispatch('getTokenInfo').then(roles => {
      Vue.use(Acl, roles, (acl) => {
        for (const role of roles) {
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
      }, { caseMode: false, router: router })
      commit('ROLES_UPDATED', roles)
    })
  },
  delete: ({ commit }) => {
    localStorage.removeItem(STORAGE_TOKEN_KEY)
    commit('TOKEN_DELETED')
    commit('USERNAME_DELETED')
    commit('ROLES_DELETED')
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
    if (params.i18n.locale !== params.lang || state.languages.indexOf(params.lang) < 0) {
      if (state.languages.indexOf(params.lang) < 0) {
        return api.getLanguage(params.lang).then(response => {
          let messages = response.data.item.lexicon
          params.i18n.setLocaleMessage(params.lang, messages)
          state.languages.push(params.lang)
          return setI18nLanguage(params.i18n, params.lang)
        })
      }
      return Promise.resolve(setI18nLanguage(params.i18n, params.lang))
    }
    return Promise.resolve(params.lang)
  }
}

const mutations = {
  TOKEN_UPDATED: (state, token) => {
    state.token = token
  },
  TOKEN_DELETED: (state) => {
    state.token = ''
  },
  USERNAME_UPDATED: (state, username) => {
    state.username = username
  },
  USERNAME_DELETED: (state) => {
    state.username = ''
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

function setI18nLanguage (i18n, lang) {
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
