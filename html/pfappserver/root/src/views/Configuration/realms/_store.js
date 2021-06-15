/**
* "$_realms" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import { apiFactory } from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_realms/isLoading']),
    getList: params => $store.dispatch('$_realms/allByTenant', params),
    getListOptions: params => {
      const { id, ..._params } = params // strip `id`
      return $store.dispatch('$_realms/options', _params)
    },
    createItem: params => $store.dispatch('$_realms/createRealm', params),
    sortItems: params => $store.dispatch('$_realms/sortRealms', params),
    getItem: params => $store.dispatch('$_realms/getRealm', params).then(item => {
      return (params.isClone)
        ? { ...item, id: `${item.id}-copy`, not_deletable: false }
        : item
    }),
    getItemOptions: params => $store.dispatch('$_realms/options', params),
    updateItem: params => $store.dispatch('$_realms/updateRealm', params),
    deleteItem: params => $store.dispatch('$_realms/deleteRealm', params),
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
    tenants: {}, // items details per tenant
    cache: {}, // items details
    message: '',
    itemStatus: ''
  }
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.itemStatus),
  isLoading: state => state.itemStatus === types.LOADING,
  tenants: state => state.tenants
}

const actions = {
  allByTenant: ({ state, commit }, tenantId) => {
    if (!state.tenants[tenantId]) {
      commit('TENANT_REQUEST', tenantId)
      const params = {
        fields: ['id']
      }
      apiFactory(tenantId).list(params).then(response => {
        commit('TENANT_SUCCESS', { tenantId, items: response.items })
      }).catch(err => {
        commit('TENANT_ERROR', err.response)
        throw err
      })
    }
    return state.tenants[tenantId]
  },
  sortRealms: ({ commit }, { tenantId, items }) => {
    const params = {
      items
    }
    commit('TENANT_REQUEST', tenantId)
    return apiFactory(tenantId).sortItems(params).then(response => {
      commit('TENANT_RESORTED', { tenantId, items })
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  options: ({ commit }, { tenantId, id }) => {
    commit('ITEM_REQUEST')
    if (id) {
      return apiFactory(tenantId).itemOptions(id).then(response => {
        commit('ITEM_SUCCESS')
        return response
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    } else {
      return apiFactory(tenantId).listOptions().then(response => {
        commit('ITEM_SUCCESS')
        return response
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    }
  },
  getRealm: ({ state, commit }, { tenantId, id }) => {
    if (state.cache[tenantId] && state.cache[tenantId][id]) {
      return state.cache[tenantId][id]
    }
    commit('ITEM_REQUEST')
    return apiFactory(tenantId).item(id).then(item => {
      commit('ITEM_REPLACED', { tenantId, item })
      return item
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createRealm: ({ commit }, { tenantId, item }) => {
    commit('ITEM_REQUEST')
    return apiFactory(tenantId).create(item).then(response => {
      commit('ITEM_REPLACED', { tenantId, item })
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateRealm: ({ commit }, { tenantId, item }) => {
    commit('ITEM_REQUEST')
    return apiFactory(tenantId).update(item).then(response => {
      commit('ITEM_REPLACED', { tenantId, item })
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteRealm: ({ commit }, { tenantId, id }) => {
    commit('ITEM_REQUEST', types.DELETING)
    return apiFactory(tenantId).delete(id).then(response => {
      commit('ITEM_DESTROYED', { tenantId, id })
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  }
}

const mutations = {
  TENANT_REQUEST: (state, tenantId) => {
    state.itemStatus = types.LOADING
    state.message = ''
    if (!state.tenants[tenantId]) {
      Vue.set(state.tenants, tenantId, []) // reactive placholder
    }
  },
  TENANT_ERROR: (state, response) => {
    state.itemStatus = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  TENANT_SUCCESS: (state, {tenantId, items}) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.tenants, tenantId, items)
  },
  TENANT_RESORTED: (state, {tenantId, items}) => {
    state.itemStatus = types.SUCCESS
    const sortedItems = items.map(id => state.tenants[tenantId].find(tenant => tenant.id === id))
    Vue.set(state.tenants, tenantId, sortedItems)
  },

  ITEM_REQUEST: (state, type) => {
    state.itemStatus = type || types.LOADING
    state.message = ''
  },
  ITEM_REPLACED: (state, { tenantId, item }) => {
    const { id } = item
    state.itemStatus = types.SUCCESS
    if (!(tenantId in state.cache)) {
      Vue.set(state.cache, tenantId, {})
    }
    Vue.set(state.cache[tenantId], id, item)
    if (tenantId in state.tenants) {
      Vue.set(state.tenants, tenantId, [ ...state.tenants[tenantId].filter(tenant => tenant.id !== id), item ])
    }
  },
  ITEM_DESTROYED: (state, { tenantId, id }) => {
    state.itemStatus = types.SUCCESS
    if (tenantId in state.cache) {
      Vue.delete(state.cache[tenantId], id)
    }
    if (tenantId in state.tenants) {
      Vue.set(state.tenants, tenantId, state.tenants[tenantId].filter(tenant => tenant.id !== id))
    }
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
