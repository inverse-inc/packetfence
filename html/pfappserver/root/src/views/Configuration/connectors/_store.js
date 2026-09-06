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

// Default values
const state = () => {
  return {
    ...stateConnectors()
  }
}

const getters = {
  ...gettersConnectors,

  isWaiting: state => [types.LOADING, types.DELETING].includes(state.connectorStatus),
  isLoading: state => state.connectorStatus === types.LOADING
}

const actions = {
  ...actionsConnectors
}

const mutations = {
  ...mutationsConnectors
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
