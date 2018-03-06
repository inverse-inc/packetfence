
import Vue from 'vue'
import Acl from 'vue-browser-acl'
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
    return apiCall({url: 'token_info', method: 'get'})
  },
  getTenants: () => {
    return apiCall({url: 'tenants', method: 'get'})
  },
  getLanguage: (locale) => {
    return Promise.resolve({ en: {} })
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
  charts: true
}

const getters = {
  isAuthenticated: state => !!state.token && state.roles.length > 0
}

const actions = {
  update: ({commit, dispatch}, token) => {
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
              action = currentAction
              target = role.substring(0, role.length - action.length - 1).toLowerCase()
              break
            }
          }
          if (!target) {
            console.warn(`No action found for ${role}`)
            action = 'access'
            target = role.toLowerCase()
          }
          console.debug('configure acl ' + action + ' => ' + target)
          acl.rule(action, target, () => true)
        }
      }, { caseMode: false })
      commit('ROLES_UPDATED', roles)
    })
  },
  delete: ({commit, dispatch}) => {
    localStorage.removeItem(STORAGE_TOKEN_KEY)
    commit('TOKEN_DELETED')
    commit('USERNAME_DELETED')
    commit('ROLES_DELETED')
  },
  getTokenInfo: ({commit, dispatch}) => {
    return api.getTokenInfo().then(response => {
      commit('USERNAME_UPDATED', response.data.item.username)
      return response.data.item.admin_roles
    })
  },
  getTenants: ({commit}) => {
    return api.getTenants().then(response => {
      commit('TENANTS_UPDATED', response.data)
    })
  },
  setLanguage: ({state, commit}, i18n, lang) => {
    if (i18n.locale !== lang) {
      if (!state.languages.contains(lang)) {
        return api.getLanguage(lang).then(messages => {
          i18n.setLocaleMessage(lang, messages)
          state.languages.push(lang)
          return setI18nLanguage(i18n, lang)
        })
      }
      return Promise.resolve(setI18nLanguage(i18n, lang))
    }
    return Promise.resolve(lang)
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
  API_ERROR: (state) => {
    state.api = false
  },
  CHARTS_ERROR: (state) => {
    state.charts = false
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
