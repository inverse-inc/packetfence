/**
* "$_tenants" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_tenants/isLoading']),
    getList: () => $store.dispatch('$_tenants/all'),
    getListOptions: () => $store.dispatch('$_tenants/options'),
    createItem: params => $store.dispatch('$_tenants/createTenant', params),
    getItem: params => $store.dispatch('$_tenants/getTenant', params.id).then(item => {
      return (params.isClone)
        ? { ...item, id: `${item.id}-copy`, not_deletable: false }
        : item
    }),
    getItemOptions: params => $store.dispatch('$_tenants/options', params.id),
    updateItem: params => $store.dispatch('$_tenants/updateTenant', params),
    deleteItem: params => $store.dispatch('$_tenants/deleteTenant', params.id),
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
  all: state => state.cache,
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.itemStatus),
  isLoading: state => state.itemStatus === types.LOADING
}

const actions = {
  all: () => {
    const params = {
      sort: 'id',
      fields: ['id'].join(','),
      limit: 1000
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  options: ({ commit }, id) => {
    commit('ITEM_REQUEST')
    if (id) {
      return api.itemOptions(id).then(response => {
        commit('ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    } else {
      return api.listOptions().then(response => {
        commit('ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    }
  },
  getTenant: ({ state, commit }, id) => {
    if (state.cache[id])
      return Promise.resolve(state.cache[id])
    commit('ITEM_REQUEST')
    return api.item(id).then(item => {
      commit('ITEM_REPLACED', item)
      return Promise.resolve(state.cache[id])
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createTenant: ({ state, commit }, data) => {
    commit('ITEM_REQUEST')
    return api.create(data).then(response => {
      const { id } = response
      commit('ITEM_REPLACED', { ...data, id })
      return Promise.resolve(state.cache[id])
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateTenant: ({ state, commit }, data) => {
    commit('ITEM_REQUEST')
    return api.update(data).then(() => {
      commit('ITEM_REPLACED', data)
      return Promise.resolve(state.cache[data.id])
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteTenant: ({ commit }, data) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.delete(data).then(response => {
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
    Vue.set(state.cache, data.id, data)
  },
  ITEM_DESTROYED: (state, id) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, id, undefined)
  },
  ITEM_ERROR: (state, response) => {
    state.itemStatus = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  ITEM_SUCCESS: (state) => {
    state.itemStatus = types.SUCCESS
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
