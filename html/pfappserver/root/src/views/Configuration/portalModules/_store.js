/**
* "$_portalmodules" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_portalmodules/isLoading']),
    getList: () => $store.dispatch('$_portalmodules/all'),
    getListOptions: params => $store.dispatch('$_portalmodules/optionsByModuleType', params.moduleType),
    createItem: params => $store.dispatch('$_portalmodules/createPortalModule', params),
    getItem: params => $store.dispatch('$_portalmodules/getPortalModule', params.id).then(item => {
      return (params.isClone)
        ? { ...item, id: `${item.id}-${i18n.t('copy')}`, not_deletable: false }
        : item
    }),
    getItemOptions: params => $store.dispatch('$_portalmodules/optionsById', params.id),
    updateItem: params => $store.dispatch('$_portalmodules/updatePortalModule', params),
    deleteItem: params => $store.dispatch('$_portalmodules/deletePortalModule', params.id),
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
    itemStatus: '',
    coordinates: {}
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
      fields: ['id', 'description', 'class'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  optionsById: ({ commit }, id) => {
    commit('ITEM_REQUEST')
    return api.itemOptions(id).then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsByModuleType: ({ commit }, moduleType) => {
    commit('ITEM_REQUEST')
    return api.listOptions(moduleType).then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getPortalModule: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id]).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.item(id).then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createPortalModule: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.create(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updatePortalModule: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.update(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deletePortalModule: ({ commit }, data) => {
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
  ITEM_SUCCESS: (state) => {
    state.itemStatus = types.SUCCESS
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
