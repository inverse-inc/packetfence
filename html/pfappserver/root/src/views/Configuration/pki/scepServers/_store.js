import { computed } from '@vue/composition-api'
import { types } from '@/store'
import api from './_api'
import {
  decomposeScepServer,
  recomposeScepServer
} from './config'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_pkis/isScepServerLoading']),
    getList: () => $store.dispatch('$_pkis/allScepServers'),
    createItem: params => $store.dispatch('$_pkis/createScepServer', recomposeScepServer(params)),
    getItem: params => $store.dispatch('$_pkis/getScepServer', params.id)
      .then(item => decomposeScepServer(item)),
    updateItem: params => $store.dispatch('$_pkis/updateScepServer', recomposeScepServer(params))
      .then(item => decomposeScepServer(item)),
    deleteItem: params => $store.dispatch('$_pkis/deleteScepServer', params.id),
  }
}

// Default values
export const state = () => {
  return {
    scepServerListCache: false, // scep server list details
    scepServerItemCache: {}, // scep server item details
    scepServerMessage: '',
    scepServerStatus: ''
  }
}

export const getters = {
  isScepServerWaiting: state => [types.LOADING, types.DELETING].includes(state.scepServerStatus),
  isScepServerLoading: state => state.scepServerStatus === types.LOADING,
  cas: state => state.scepServerListCache
}

export const actions = {
  allScepServers: ({ state, commit }) => {
    if (state.scepServerListCache) {
      return Promise.resolve(state.scepServerListCache)
    }
    commit('SCEPSERVER_REQUEST')
    return api.list().then(response => {
      commit('SCEPSERVER_LIST_REPLACED', response.items)
      return state.scepServerListCache
    }).catch((err) => {
      commit('SCEPSERVER_ERROR', err.response)
      throw err
    })
  },
  getScepServer: ({ state, commit }, id) => {
    if (state.scepServerItemCache[id]) {
      return Promise.resolve(state.scepServerItemCache[id])
    }
    commit('SCEPSERVER_REQUEST')
    return api.item(id).then(item => {
      commit('SCEPSERVER_ITEM_REPLACED', item)
      return state.scepServerItemCache[id]
    }).catch((err) => {
      commit('SCEPSERVER_ERROR', err.response)
      throw err
    })
  },
  createScepServer: ({ commit, dispatch }, data) => {
    commit('SCEPSERVER_REQUEST')
    return api.create(data).then(item => {
      // reset list
      commit('SCEPSERVER_LIST_RESET')
      dispatch('allScepServers')
      // update item
      commit('SCEPSERVER_ITEM_REPLACED', item)
      return item
    }).catch(err => {
      commit('SCEPSERVER_ERROR', err.response)
      throw err
    })
  },
  updateScepServer: ({ commit, dispatch }, data) => {
    commit('SCEPSERVER_REQUEST')
    return api.update(data).then(item => {
      // reset list
      commit('SCEPSERVER_LIST_RESET')
      dispatch('allScepServers')
      // update item
      commit('SCEPSERVER_ITEM_REPLACED', item)
      return item
    }).catch(err => {
      commit('SCEPSERVER_ERROR', err.response)
      throw err
    })
  },
  deleteScepServer: ({ commit, dispatch }, id) => {
    commit('SCEPSERVER_REQUEST', types.DELETING)
    return api.delete(id).then(item => {
      // reset list
      commit('SCEPSERVER_LIST_RESET')
      dispatch('allScepServers')
      // update item
      commit('SCEPSERVER_ITEM_DESTROYED', id)
      return item
    }).catch(err => {
      commit('SCEPSERVER_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  SCEPSERVER_REQUEST: (state, type) => {
    state.scepServerStatus = type || types.LOADING
    state.scepServerMessage = ''
  },
  SCEPSERVER_LIST_RESET: (state) => {
    state.scepServerListCache = false
  },
  SCEPSERVER_LIST_REPLACED: (state, items) => {
    state.scepServerStatus = types.SUCCESS
    state.scepServerListCache = items
  },
  SCEPSERVER_ITEM_REPLACED: (state, data) => {
    state.scepServerStatus = types.SUCCESS
    state.scepServerItemCache[data.id] = data
  },
  SCEPSERVER_ITEM_DESTROYED: (state, id) => {
    state.scepServerStatus = types.SUCCESS
    state.scepServerItemCache[id] = undefined
  },
  SCEPSERVER_ERROR: (state, response) => {
    state.scepServerStatus = types.ERROR
    if (response && response.data) {
      state.scepServerMessage = response.data.message
    }
  }
}
