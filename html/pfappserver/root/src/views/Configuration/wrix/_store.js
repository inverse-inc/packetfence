/**
* "$_wrix_locations" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_wrix_locations/isLoading']),
    getList: () => $store.dispatch('$_wrix_locations/all'),
    createItem: params => $store.dispatch('$_wrix_locations/createWrixLocation', params),
    getItem: params => $store.dispatch('$_wrix_locations/getWrixLocation', params.id).then(item => {
      return (params.isClone)
        ? { ...item, id: `${item.id}-copy`, not_deletable: false }
        : item
    }),
    updateItem: params => $store.dispatch('$_wrix_locations/updateWrixLocation', params),
    deleteItem: params => $store.dispatch('$_wrix_locations/deleteWrixLocation', params.id),
  }
}

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const state = () => {
  return {
    cache: {}, // items details
    message: '',
    itemStatus: ''
  }
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.itemStatus),
  isLoading: state => state.itemStatus === types.LOADING
}

const actions = {
  all: () => {
    const params = {
      sort: 'id',
      fields: ['id', 'type'].join(',')
    }
    return api.wrixLocations(params).then(response => {
      return response.items
    })
  },
  getWrixLocation: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id]).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.wrixLocation(id).then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createWrixLocation: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.createWrixLocation(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateWrixLocation: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.updateWrixLocation(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteWrixLocation: ({ commit }, data) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.deleteWrixLocation(data).then(response => {
      commit('ITEM_DESTROYED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  }
}

const mutations = {
  ITEM_REQUEST: (state, type) => {
    state.itemStatus = type || types.LOADING
    state.message = ''
  },
  ITEM_REPLACED: (state, data) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, data.id, JSON.parse(JSON.stringify(data)))
  },
  ITEM_DESTROYED: (state, id) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, id, null)
  },
  ITEM_ERROR: (state, response) => {
    state.itemStatus = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
    }
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
