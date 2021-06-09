/**
* "$_pkis" store module
*/
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


const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const state = () => {
  return {
    ...stateCas(),
    ...stateProfiles(),
    ...stateCerts(),
    ...stateRevokedCerts()
  }
}

const getters = {
  ...gettersCas,
  ...gettersProfiles,
  ...gettersCerts,
  ...gettersRevokedCerts,

  isWaiting: state => [types.LOADING, types.DELETING].includes(state.caStatus) || [types.LOADING, types.DELETING].includes(state.profileStatus) || [types.LOADING, types.DELETING].includes(state.certStatus) || [types.LOADING, types.DELETING].includes(state.revokedCertStatus),
  isLoading: state => state.caStatus === types.LOADING || state.profileStatus === types.LOADING || state.certStatus === types.LOADING || state.revokedCertStatus === types.LOADING
}

const actions = {
  ...actionsCas,
  ...actionsProfiles,
  ...actionsCerts,
  ...actionsRevokedCerts
}

const mutations = {
  ...mutationsCas,
  ...mutationsProfiles,
  ...mutationsCerts,
  ...mutationsRevokedCerts
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
