import Vue from 'vue'
import api from './_api'

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
export const state = () => {
  return {
    generalSettings: {
      cache: false,
      message: '',
      status: ''
    }
  }
}

export const getters = {
  isGeneralSettingsWaiting: state => [types.LOADING, types.DELETING].includes(state.generalSettings.status),
  isGeneralSettingsLoading: state => state.generalSettings.status === types.LOADING
}

export const actions = {
  getGeneralSettings: ({ state, commit }) => {
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
  },
  GENERAL_SETTINGS_ERROR: (state, response) => {
    state.generalSettings.status = types.ERROR
    if (response && response.data) {
      state.generalSettings.message = response.data.message
    }
  },
  GENERAL_SETTINGS_SUCCESS: (state) => {
    state.generalSettings.status = types.SUCCESS
  }
}
