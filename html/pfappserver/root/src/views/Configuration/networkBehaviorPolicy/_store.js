/**
* "$_network_behavior_policies" store module
*/
import Vue from 'vue'
import api from './_api'

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
    policiesPromise: null
  }
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.itemStatus),
  isLoading: state => state.itemStatus === types.LOADING
}

const actions = {
  all: ({ state, commit }) => {
    const params = {
      sort: 'id',
      fields: ['id', 'description'].join(',')
    }
    if (!state.policiesPromise) {
      commit('ITEM_REQUEST')
      state.policiesPromise = api.list(params).then(response => {
        commit('ITEM_SUCCESS')
        return response.items
      }).catch((err) => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    }
    return state.policiesPromise
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
  getNetworkBehaviorPolicy: ({ state, commit }, id) => {
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
  createNetworkBehaviorPolicy: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.create(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateNetworkBehaviorPolicy: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.update(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  enableNetworkBehaviorPolicy: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    const { id, quiet = false } = data
    const _data = { id, status: 'enabled', quiet }
    return api.update(_data).then(response => {
      commit('ITEM_ENABLED', _data)
      commit('$_config_network_behavior_policies_searchable/ITEM_UPDATED', { key: 'id', id, prop: 'status', data: 'enabled' }, { root: true })
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  disableNetworkBehaviorPolicy: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    const { id, quiet = false } = data
    const _data = { id, status: 'disabled', quiet }
    return api.update(_data).then(response => {
      commit('ITEM_DISABLED', _data)
      commit('$_config_network_behavior_policies_searchable/ITEM_UPDATED', { key: 'id', id, prop: 'status', data: 'disabled' }, { root: true })
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteNetworkBehaviorPolicy: ({ commit }, data) => {
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
    Vue.set(state.cache, data.id, JSON.parse(JSON.stringify(data)))
  },
  ITEM_ENABLED: (state, data) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, data.id, { ...state.cache[data.id], ...data })
  },
  ITEM_DISABLED: (state, data) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, data.id, { ...state.cache[data.id], ...data })
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
