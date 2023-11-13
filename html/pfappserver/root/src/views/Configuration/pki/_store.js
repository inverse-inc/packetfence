/**
* "$_pkis" store module
*/
import { types } from '@/store'

import {
  state as stateCas,
  getters as gettersCas,
  actions as actionsCas,
  mutations as mutationsCas
} from './cas/_store'

import {
  state as stateProfiles,
  getters as gettersProfiles,
  actions as actionsProfiles,
  mutations as mutationsProfiles
} from './profiles/_store'

import {
  state as stateCerts,
  getters as gettersCerts,
  actions as actionsCerts,
  mutations as mutationsCerts
} from './certs/_store'

import {
  state as stateRevokedCerts,
  getters as gettersRevokedCerts,
  actions as actionsRevokedCerts,
  mutations as mutationsRevokedCerts
} from './revokedCerts/_store'

import {
  state as stateScepServers,
  getters as gettersScepServers,
  actions as actionsScepServers,
  mutations as mutationsScepServers
} from './scepServers/_store'

// Default values
const state = () => {
  return {
    ...stateCas(),
    ...stateProfiles(),
    ...stateCerts(),
    ...stateRevokedCerts(),
    ...stateScepServers()
  }
}

const getters = {
  ...gettersCas,
  ...gettersProfiles,
  ...gettersCerts,
  ...gettersRevokedCerts,
  ...gettersScepServers,

  isWaiting: state => [types.LOADING, types.DELETING].includes(state.caStatus) || [types.LOADING, types.DELETING].includes(state.profileStatus) || [types.LOADING, types.DELETING].includes(state.certStatus) || [types.LOADING, types.DELETING].includes(state.revokedCertStatus) || [types.LOADING, types.DELETING].includes(state.scepServerStatus),
  isLoading: state => state.caStatus === types.LOADING || state.profileStatus === types.LOADING || state.certStatus === types.LOADING || state.revokedCertStatus === types.LOADING || state.scepServerStatus === types.LOADING
}

const actions = {
  ...actionsCas,
  ...actionsProfiles,
  ...actionsCerts,
  ...actionsRevokedCerts,
  ...actionsScepServers
}

const mutations = {
  ...mutationsCas,
  ...mutationsProfiles,
  ...mutationsCerts,
  ...mutationsRevokedCerts,
  ...mutationsScepServers
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
