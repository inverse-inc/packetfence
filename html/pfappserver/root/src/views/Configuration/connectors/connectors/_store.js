import Vue from 'vue'
import { types } from '@/store'
import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_connectors/isConnectorLoading']),
    getList: () => $store.dispatch('$_connectors/allConnectors'),
    getListOptions: () => $store.dispatch('$_connectors/optionsConnectors'),
    sortItems: params => $store.dispatch('$_connectors/sortConnectors', params.items),
    createItem: params => $store.dispatch('$_connectors/createConnector', params),
    getItem: params => $store.dispatch('$_connectors/getConnector', params.id).then(item => {
      return (params.isClone)
        ? { ...item, id: `${item.id}-${i18n.t('copy')}`, not_deletable: false }
        : item
    }),
    getItemOptions: params => $store.dispatch('$_connectors/optionsConnectors', params.id),
    updateItem: params => $store.dispatch('$_connectors/updateConnector', params),
    deleteItem: params => $store.dispatch('$_connectors/deleteConnector', params.id),
  }
}

// Default values
export const state = () => {
  return {
    connectorCache: {}, // items details
    connectorMessage: '',
    connectorStatus: ''
  }
}

export const getters = {
  isConnectorWaiting: state => [types.LOADING, types.DELETING].includes(state.connectorStatus),
  isConnectorLoading: state => state.connectorStatus === types.LOADING
}

export const actions = {
  allConnectors: () => {
    const params = {
      sort: 'id',
      fields: ['id', 'description'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  optionsConnectors: ({ commit }, id) => {
    commit('CONNECTOR_ITEM_REQUEST')
    if (id) {
      return api.itemOptions(id).then(response => {
        commit('CONNECTOR_ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('CONNECTOR_ITEM_ERROR', err.response)
        throw err
      })
    } else {
      return api.listOptions().then(response => {
        commit('CONNECTOR_ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('CONNECTOR_ITEM_ERROR', err.response)
        throw err
      })
    }
  },
  getConnector: ({ state, commit }, id) => {
    if (state.connectorCache[id]) {
      return Promise.resolve(state.connectorCache[id]).then(connectorCache => JSON.parse(JSON.stringify(connectorCache)))
    }
    commit('CONNECTOR_ITEM_REQUEST')
    return api.item(id).then(item => {
      commit('CONNECTOR_ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('CONNECTOR_ITEM_ERROR', err.response)
      throw err
    })
  },
  createConnector: ({ commit }, data) => {
    commit('CONNECTOR_ITEM_REQUEST')
    return api.create(data).then(response => {
      commit('CONNECTOR_ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('CONNECTOR_ITEM_ERROR', err.response)
      throw err
    })
  },
  updateConnector: ({ commit }, data) => {
    commit('CONNECTOR_ITEM_REQUEST')
    return api.update(data).then(response => {
      commit('CONNECTOR_ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('CONNECTOR_ITEM_ERROR', err.response)
      throw err
    })
  },
  sortConnectors: ({ commit }, data) => {
    const params = {
      items: data
    }
    commit('CONNECTOR_ITEM_REQUEST', types.LOADING)
    return api.sort(params).then(response => {
      commit('CONNECTOR_ITEM_SUCCESS')
      return response
    }).catch(err => {
      commit('CONNECTOR_ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteConnector: ({ commit }, id) => {
    commit('CONNECTOR_ITEM_REQUEST', types.DELETING)
    return api.delete(id).then(response => {
      commit('CONNECTOR_ITEM_DESTROYED', id)
      return response
    }).catch(err => {
      commit('CONNECTOR_ITEM_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  CONNECTOR_ITEM_REQUEST: (state, type) => {
    state.connectorStatus = type || types.LOADING
    state.connectorMessage = ''
  },
  CONNECTOR_ITEM_REPLACED: (state, data) => {
    state.connectorStatus = types.SUCCESS
    Vue.set(state.connectorCache, data.id, JSON.parse(JSON.stringify(data)))
  },
  CONNECTOR_ITEM_DESTROYED: (state, id) => {
    state.connectorStatus = types.SUCCESS
    Vue.set(state.connectorCache, id, null)
  },
  CONNECTOR_ITEM_ERROR: (state, response) => {
    state.connectorStatus = types.ERROR
    if (response && response.data) {
      state.connectorMessage = response.data.message
    }
  },
  CONNECTOR_ITEM_SUCCESS: (state) => {
    state.connectorStatus = types.SUCCESS
  }
}
