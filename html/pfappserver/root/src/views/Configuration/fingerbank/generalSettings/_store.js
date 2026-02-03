import Vue from 'vue'
import { types } from '@/store'
import api from './_api'

// Default values
export const state = () => {
  return {
    generalSettings: {
      cache: false,
      message: '',
      status: '',
      environment: {}
    }
  }
}

export const getters = {
  apiKey: ({ generalSettings: { cache: { upstream: { api_key } = {} } = {} } = {} }) => api_key,
  environment: state => state.generalSettings.environment,
  isGeneralSettingsWaiting: state => [types.LOADING, types.DELETING].includes(state.generalSettings.status),
  isGeneralSettingsLoading: state => state.generalSettings.status === types.LOADING
}

export const actions = {
  getGeneralSettings: ({ state, getters, commit }) => {
    if (state.generalSettings.cache) {
      return Promise.resolve(state.generalSettings.cache)
    }
    commit('GENERAL_SETTINGS_REQUEST')
    const params = {
      sort: 'id'
    }
    return api.fingerbankGeneralSettings(params).then(response => {
      // response is split multipart, refactor required
      let refactored = {}
      response.forEach((section) => {
        refactored[section.id] = Object.keys(section)
          .filter(key => !(['id'].includes(key)))
          .reduce((obj, key) => {
            obj[key] = section[key]
            return obj
          }, {})
      })
      commit('GENERAL_SETTINGS_REPLACED', refactored)
      if (getters.apiKey) {
        api.fingerbankCollectorFlags(getters.apiKey).then(response => {
          //eslint-disable-next-line no-unused-vars
          const environment = Object.entries(response || {}).reduce((o, [key, flag]) => {
             
            const { default: _default, usage } = flag
            //eslint-disable-next-line no-unused-vars
            const [ env, _ ] = usage.match(/([A-Z]+_[A-Z_]+[A-Z]+)/) || []
            if (env) {
              o[env] = { text: usage, value: _default }
            }
            return o
          }, {})
          commit('FINGERBANK_COLLECTOR_ENV', environment)
        })
      }
      return refactored
    }).catch(err => {
      commit('GENERAL_SETTINGS_ERROR', err.response)
      throw err
    })
  },
  // TODO - Test (Issue #4139)
  optionsGeneralSettings: ({ commit }) => {
    commit('GENERAL_SETTINGS_REQUEST')
    return api.fingerbankGeneralSettingsOptions().then(response => {
      commit('GENERAL_SETTINGS_SUCCESS')
      return response
    }).catch(err => {
      commit('GENERAL_SETTINGS_ERROR', err.response)
      throw err
    })
  },
  setGeneralSettings: ({ commit, dispatch }, data) => {
    commit('GENERAL_SETTINGS_REQUEST')
    let promises = []
    Object.keys(data).forEach(id => {
      let refactored = { ...data[id], ...{ id } }
      promises.push(api.fingerbankUpdateGeneralSetting(id, refactored))
    })
    return Promise.all(promises).then(response => {
      commit('GENERAL_SETTINGS_REPLACED', data)
      return response
    }).catch(err => {
      commit('GENERAL_SETTINGS_ERROR', err.response)
      throw err
    }).finally(() => {
      commit('ACCOUNT_INFO_RESET')
      dispatch('getAccountInfo')
    })
  }
}

export const mutations = {
  GENERAL_SETTINGS_REQUEST: (state, type) => {
    state.generalSettings.status = type || types.LOADING
    state.generalSettings.message = ''
  },
  GENERAL_SETTINGS_REPLACED: (state, data) => {
    state.generalSettings.status = types.SUCCESS
    if (!state.generalSettings.cache)
      Vue.set(state.generalSettings, 'cache', {})
    for (let id of Object.keys(data)) {
      Vue.set(state.generalSettings.cache, id, data[id])
    }
    const { upstream: { api_key } = {} } = data
    state.generalSettings.api_key = api_key
  },
  GENERAL_SETTINGS_ERROR: (state, response) => {
    state.generalSettings.status = types.ERROR
    if (response && response.data) {
      state.generalSettings.message = response.data.message
    }
  },
  GENERAL_SETTINGS_SUCCESS: (state) => {
    state.generalSettings.status = types.SUCCESS
  },
  FINGERBANK_COLLECTOR_ENV: (state, environment) => {
    state.generalSettings.environment = environment
  }
}
