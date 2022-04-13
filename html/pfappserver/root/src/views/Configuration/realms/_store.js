/**
* "$_realms" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import store from '@/store'
import i18n from '@/utils/locale'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_realms/isLoading']),
    getList: params => $store.dispatch('$_realms/all', params),
    getListOptions: () => $store.dispatch('$_realms/options'),
    createItem: params => $store.dispatch('$_realms/createRealm', params),
    sortItems: params => $store.dispatch('$_realms/sortRealms', params.items),
    getItem: params => $store.dispatch('$_realms/getRealm', params.id).then(item => {
      return (params.isClone)
        ? { ...item, id: `${item.id}-${i18n.t('copy')}`, not_deletable: false }
        : item
    }),
    getItemOptions: params => $store.dispatch('$_realms/options', params.id),
    updateItem: params => $store.dispatch('$_realms/updateRealm', params),
    deleteItem: params => $store.dispatch('$_realms/deleteRealm', params.id),
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
      fields: ['id'].join(','),
      limit: 1000
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  sortRealms: ({ commit }, items) => {
    commit('ITEM_REQUEST')
    return api.sortItems({ items }).then(response => {
      commit('ITEMS_RESORTED', items)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  options: ({ commit }, id) => {
    commit('ITEM_REQUEST')
    if (id) {
      return api.itemOptions(id).then(response => {
        commit('ITEM_SUCCESS')
        return response
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    } else {
      return api.listOptions().then(response => {
        commit('ITEM_SUCCESS')
        return response
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    }
  },
  getRealm: ({ state, commit }, id) => {
    if (state.cache && state.cache[id]) {
      return state.cache[id]
    }
    commit('ITEM_REQUEST')
    return api.item(id).then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createRealm: ({ commit }, item) => {
    commit('ITEM_REQUEST')
    return api.create(item).then(response => {
      commit('ITEM_REPLACED', item)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateRealm: ({ commit }, item) => {
    commit('ITEM_REQUEST')
    return api.update(item).then(response => {
      commit('ITEM_REPLACED', item)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteRealm: ({ commit }, id) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.delete(id).then(response => {
      commit('ITEM_DESTROYED', id)
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
  ITEM_REPLACED: (state, item) => {
    const { id } = item
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, id, item)
    store.dispatch('config/resetRealms')
  },
  ITEMS_RESORTED: (state, items) => {
    state.itemStatus = types.SUCCESS
    let sorted = Object.values(state.cache).sort((a, b) => {
      return items.findIndex(i => i === a.id) - items.findIndex(i => i === b.id)
    })
    Vue.set(state, 'cache', sorted)
    store.dispatch('config/resetRealms')
  },
  ITEM_DESTROYED: (state, id) => {
    state.itemStatus = types.SUCCESS
    Vue.delete(state.cache, id)
    store.dispatch('config/resetRealms')
  },
  ITEM_ERROR: (state, response) => {
    state.itemStatus = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  ITEM_SUCCESS: (state) => {
    state.itemStatus = types.SUCCESS
  },
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
