import { computed } from '@vue/composition-api'
import { types } from '@/store'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_pkis/isHsmLoading']),
    getList: () => $store.dispatch('$_pkis/allHsms'),
    createItem: params => $store.dispatch('$_pkis/createHsm', params),
    getItem: params => $store.dispatch('$_pkis/getHsm', params.id),
    updateItem: params => $store.dispatch('$_pkis/updateHsm', params),
    deleteItem: params => $store.dispatch('$_pkis/deleteHsm', params.id),
  }
}

// Default values
export const state = () => {
  return {
    hsmListCache: false, // hsm list details
    hsmItemCache: {}, // hsm item details
    hsmMessage: '',
    hsmStatus: ''
  }
}

export const getters = {
  isHsmWaiting: state => [types.LOADING, types.DELETING].includes(state.hsmStatus),
  isHsmLoading: state => state.hsmStatus === types.LOADING,
  hsms: state => state.hsmListCache
}

export const actions = {
  allHsms: ({ state, commit }) => {
    if (state.hsmListCache) {
      return Promise.resolve(state.hsmListCache)
    }
    commit('HSM_REQUEST')
    return api.list().then(response => {
      commit('HSM_LIST_REPLACED', response.items)
      return state.hsmListCache
    }).catch((err) => {
      commit('HSM_ERROR', err.response)
      throw err
    })
  },
  getHsm: ({ state, commit }, id) => {
    if (state.hsmItemCache[id]) {
      return Promise.resolve(state.hsmItemCache[id])
    }
    commit('HSM_REQUEST')
    return api.item(id).then(item => {
      commit('HSM_ITEM_REPLACED', item)
      return state.hsmItemCache[id]
    }).catch((err) => {
      commit('HSM_ERROR', err.response)
      throw err
    })
  },
  createHsm: ({ commit, dispatch }, data) => {
    commit('HSM_REQUEST')
    return api.create(data).then(item => {
      // reset list
      commit('HSM_LIST_RESET')
      dispatch('allHsms')
      dispatch('config/resetPkiHsms', null, { root: true })
      // update item
      commit('HSM_ITEM_REPLACED', item)
      return item
    }).catch(err => {
      commit('HSM_ERROR', err.response)
      throw err
    })
  },
  updateHsm: ({ commit, dispatch }, data) => {
    commit('HSM_REQUEST')
    return api.update(data).then(item => {
      // reset list
      commit('HSM_LIST_RESET')
      dispatch('allHsms')
      dispatch('config/resetPkiHsms', null, { root: true })
      // update item
      commit('HSM_ITEM_REPLACED', item)
      return item
    }).catch(err => {
      commit('HSM_ERROR', err.response)
      throw err
    })
  },
  deleteHsm: ({ commit, dispatch }, id) => {
    commit('HSM_REQUEST', types.DELETING)
    return api.delete(id).then(item => {
      // reset list
      commit('HSM_LIST_RESET')
      dispatch('allHsms')
      dispatch('config/resetPkiHsms', null, { root: true })
      // update item
      commit('HSM_ITEM_DESTROYED', id)
      return item
    }).catch(err => {
      commit('HSM_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  HSM_REQUEST: (state, type) => {
    state.hsmStatus = type || types.LOADING
    state.hsmMessage = ''
  },
  HSM_LIST_RESET: (state) => {
    state.hsmListCache = false
  },
  HSM_LIST_REPLACED: (state, items) => {
    state.hsmStatus = types.SUCCESS
    state.hsmListCache = items
  },
  HSM_ITEM_REPLACED: (state, data) => {
    state.hsmStatus = types.SUCCESS
    state.hsmItemCache[data.id] = data
  },
  HSM_ITEM_DESTROYED: (state, id) => {
    state.hsmStatus = types.SUCCESS
    state.hsmItemCache[id] = undefined
  },
  HSM_ERROR: (state, response) => {
    state.hsmStatus = types.ERROR
    if (response && response.data) {
      state.hsmMessage = response.data.message
    }
  }
}
