/**
* "$_domains" store module
*/
import Vue from 'vue'
import { types } from '@/store'
import { computed } from '@vue/composition-api'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_domains/isLoading']),
    getList: () => $store.dispatch('$_domains/all'),
    getListOptions: () => $store.dispatch('$_domains/options'),
    createItem: params => $store.dispatch('$_domains/createDomain', params),
    getItem: params => $store.dispatch('$_domains/getDomain', params.id).then(item => {
      return (params.isClone)
        ? { ...item, id: `${item.id}copy`, not_deletable: false }
        : item
    }),
    getItemOptions: params => $store.dispatch('$_domains/options', params.id),
    updateItem: params => $store.dispatch('$_domains/updateDomain', params),
    deleteItem: params => $store.dispatch('$_domains/deleteDomain', params.id),
    testItem: params => $store.dispatch('$_domains/testMachineAccount', params)
  }
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
      fields: ['id', 'workgroup', 'ntlm_cache'].join(',')
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
  getDomain: ({ state, commit }, id) => {
    if (state.cache[id])
      return Promise.resolve(state.cache[id])
    commit('ITEM_REQUEST')
    return api.item(id).then(item => {
      commit('ITEM_REPLACED', item)
      return state.cache[id]
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createDomain: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.create(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateDomain: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.update(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteDomain: ({ commit }, data) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.delete(data).then(response => {
      commit('ITEM_DESTROYED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  testMachineAccount: ({commit}, data) => {
    commit('ITEM_REQUEST')
    return api.testMachineAccount(data).then(response => {
      commit('ITEM_SUCCESS', data)
      return response.message
    }).catch(err => {
      commit('ITEM_ERROR', err.response.message)
      throw err.response.data.message
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
    Vue.set(state.cache, id, null)
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
