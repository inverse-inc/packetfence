/**
* "$_fingerbank" store module
*/
import Vue from 'vue'
import api from './_api'

import {
  state as stateGeneralSettings,
  getters as gettersGeneralSettings,
  actions as actionsGeneralSettings,
  mutations as mutationsGeneralSettings
} from './generalSettings/_store'

import {
  state as stateCombinations,
  getters as gettersCombinations,
  actions as actionsCombinations,
  mutations as mutationsCombinations
} from './combinations/_store'

import {
  state as stateDevices,
  getters as gettersDevices,
  actions as actionsDevices,
  mutations as mutationsDevices
} from './devices/_store'

import {
  state as stateDhcpFingerprints,
  getters as gettersDhcpFingerprints,
  actions as actionsDhcpFingerprints,
  mutations as mutationsDhcpFingerprints
} from './dhcpFingerprints/_store'

import {
  state as stateDhcpVendors,
  getters as gettersDhcpVendors,
  actions as actionsDhcpVendors,
  mutations as mutationsDhcpVendors
} from './dhcpVendors/_store'

import {
  state as stateDhcpv6Fingerprints,
  getters as gettersDhcpv6Fingerprints,
  actions as actionsDhcpv6Fingerprints,
  mutations as mutationsDhcpv6Fingerprints
} from './dhcpv6Fingerprints/_store'

import {
  state as stateDhcpv6Enterprises,
  getters as gettersDhcpv6Enterprises,
  actions as actionsDhcpv6Enterprises,
  mutations as mutationsDhcpv6Enterprises
} from './dhcpv6Enterprises/_store'

import {
  state as stateMacVendors,
  getters as gettersMacVendors,
  actions as actionsMacVendors,
  mutations as mutationsMacVendors
} from './macVendors/_store'

import {
  state as stateUserAgents,
  getters as gettersUserAgents,
  actions as actionsUserAgents,
  mutations as mutationsUserAgents
} from './userAgents/_store'

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const state = () => {
  return {
    ...stateGeneralSettings(),
    ...stateCombinations(),
    ...stateDevices(),
    ...stateDhcpFingerprints(),
    ...stateDhcpVendors(),
    ...stateDhcpv6Fingerprints(),
    ...stateDhcpv6Enterprises(),
    ...stateMacVendors(),
    ...stateUserAgents(),

    accountInfo: {
      cache: false,
      message: '',
      status: ''
    },
    canUseNbaEndpoints: {
      cache: false,
      message: '',
      status: ''
    },
    updateDatabase: {
      message: '',
      status: ''
    }
  }
}

const getters = {
  ...gettersGeneralSettings,
  ...gettersCombinations,
  ...gettersDevices,
  ...gettersDhcpFingerprints,
  ...gettersDhcpVendors,
  ...gettersDhcpv6Fingerprints,
  ...gettersDhcpv6Enterprises,
  ...gettersMacVendors,
  ...gettersUserAgents,

  accountInfo: state => state.accountInfo.cache,
  isAccountInfoWaiting: state => [types.LOADING, types.DELETING].includes(state.accountInfo.status),
  isAccountInfoLoading: state => state.accountInfo.status === types.LOADING,

  isCanUseNbaEndpointsWaiting: state => [types.LOADING, types.DELETING].includes(state.canUseNbaEndpoints.status),
  isCanUseNbaEndpointsLoading: state => state.canUseNbaEndpoints.status === types.LOADING,

  isUpdateDatabaseLoading: state => state.updateDatabase.status === types.LOADING
}

const actions = {
  ...actionsGeneralSettings,
  ...actionsCombinations,
  ...actionsDevices,
  ...actionsDhcpFingerprints,
  ...actionsDhcpVendors,
  ...actionsDhcpv6Fingerprints,
  ...actionsDhcpv6Enterprises,
  ...actionsMacVendors,
  ...actionsUserAgents,

  getAccountInfo: ({ state, commit }) => {
    if (state.accountInfo.cache) {
      return Promise.resolve(state.accountInfo.cache)
    }
    commit('ACCOUNT_INFO_REQUEST')
    return api.fingerbankAccountInfo().then(info => {
      commit('ACCOUNT_INFO_REPLACED', info)
      return info
    }).catch(err => {
      commit('ACCOUNT_INFO_ERROR', err.response)
      throw err
    })
  },
  getCanUseNbaEndpoints: ({ state, commit }) => {
    if (state.canUseNbaEndpoints.cache) {
      return Promise.resolve(state.canUseNbaEndpoints.cache)
    }
    commit('CAN_USE_NBA_ENDPOINTS_REQUEST')
    return api.fingerbankCanUseNbaEndpoints().then(info => {
      commit('CAN_USE_NBA_ENDPOINTS_REPLACED', info)
      return info
    }).catch(err => {
      commit('CAN_USE_NBA_ENDPOINTS_ERROR', err.response)
      throw err
    })
  },
  updateDatabase: ({ commit }, data) => {
    commit('UPDATE_DATABASE_REQUEST')
    return api.fingerbankUpdateDatabase().then(response => {
      commit('UPDATE_DATABASE_SUCCESS', data)
      return response
    }).catch(err => {
      commit('UPDATE_DATABASE_ERROR', err.response)
      throw err
    })
  }
}

const mutations = {
  ...mutationsGeneralSettings,
  ...mutationsCombinations,
  ...mutationsDevices,
  ...mutationsDhcpFingerprints,
  ...mutationsDhcpVendors,
  ...mutationsDhcpv6Fingerprints,
  ...mutationsDhcpv6Enterprises,
  ...mutationsMacVendors,
  ...mutationsUserAgents,

  ACCOUNT_INFO_REQUEST: (state, type) => {
    state.accountInfo.status = type || types.LOADING
    state.accountInfo.message = ''
  },
  ACCOUNT_INFO_REPLACED: (state, data) => {
    state.accountInfo.status = types.SUCCESS
    Vue.set(state.accountInfo, 'cache', data)
  },
  ACCOUNT_INFO_RESET: (state) => {
    Vue.set(state.accountInfo, 'cache', false)
  },
  ACCOUNT_INFO_ERROR: (state, response) => {
    state.accountInfo.status = types.ERROR
    if (response && response.data) {
      state.accountInfo.message = response.data.message
    }
  },
  CAN_USE_NBA_ENDPOINTS_REQUEST: (state, type) => {
    state.canUseNbaEndpoints.status = type || types.LOADING
    state.canUseNbaEndpoints.message = ''
  },
  CAN_USE_NBA_ENDPOINTS_REPLACED: (state, data) => {
    state.canUseNbaEndpoints.status = types.SUCCESS
    Vue.set(state.canUseNbaEndpoints, 'cache', data)
  },
  CAN_USE_NBA_ENDPOINTS_ERROR: (state, response) => {
    state.canUseNbaEndpoints.status = types.ERROR
    if (response && response.data) {
      state.canUseNbaEndpoints.message = response.data.message
    }
  },
  UPDATE_DATABASE_REQUEST: (state, type) => {
    state.updateDatabase.status = type || types.LOADING
    state.updateDatabase.message = ''
  },
  UPDATE_DATABASE_ERROR: (state, response) => {
    state.updateDatabase.status = types.ERROR
    if (response && response.data) {
      state.updateDatabase.message = response.data.message
    }
  },
  UPDATE_DATABASE_SUCCESS: (state) => {
    state.updateDatabase.status = types.SUCCESS
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
