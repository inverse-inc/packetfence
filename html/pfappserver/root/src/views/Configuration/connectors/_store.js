/**
* "$_connectors" store module
*/
import { types } from '@/store'

import {
  state as stateConnectors,
  getters as gettersConnectors,
  actions as actionsConnectors,
  mutations as mutationsConnectors
} from './connectors/_store'

import {
  state as stateDns,
  getters as gettersDns,
  actions as actionsDns,
  mutations as mutationsDns
} from './dns/_store'

import {
  state as stateDomains,
  getters as gettersDomains,
  actions as actionsDomains,
  mutations as mutationsDomains
} from './domains/_store'

// Default values
const state = () => {
  return {
    ...stateConnectors(),
    ...stateDns(),
    ...stateDomains()
  }
}

const getters = {
  ...gettersConnectors,
  ...gettersDns,
  ...gettersDomains,

  isWaiting: state => [types.LOADING, types.DELETING].includes(state.connectorStatus) || [types.LOADING, types.DELETING].includes(state.dnStatus) || [types.LOADING, types.DELETING].includes(state.domainStatus),
  isLoading: state => state.connectorStatus === types.LOADING || state.dnStatus === types.LOADING || state.domainStatus === types.LOADING
}

const actions = {
  ...actionsConnectors,
  ...actionsDns,
  ...actionsDomains
}

const mutations = {
  ...mutationsConnectors,
  ...mutationsDns,
  ...mutationsDomains
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
