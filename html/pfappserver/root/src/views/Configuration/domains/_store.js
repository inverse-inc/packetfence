/**
* "$_domains" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import store from '@/store' // required for 'pfqueue'
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
    joins: {}, // domain join details
    message: '',
    itemStatus: ''
  }
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.itemStatus),
  isLoading: state => state.itemStatus === types.LOADING,
  joins: state => state.joins
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
  testDomain: ({ state, commit }, id) => {
    if (id in state.joins)
      return Promise.resolve(state.joins[id])
    commit('TEST_REQUEST', id)
    return api.test(id).then(response => {
      commit('TEST_SUCCESS', { id, response })
      return state.joins[id]
    }).catch(error => {
      commit('TEST_ERROR', { id, error })
      return state.joins[id]
    })
  },
  joinDomain: ({ state, commit }, data) => {
    commit('JOIN_REQUEST', data.id)
    return api.join(data).then(response => {
      return store.dispatch('pfqueue/pollTaskStatus', response.task_id).then(response => {
        commit('JOIN_SUCCESS', { id: data.id, response })
        return state.joins[data.id]
      })
    }).catch(error => {
      commit('JOIN_ERROR', { id: data.id, response: error })
      return state.joins[data.id]
    })
  },
  rejoinDomain: ({ state, commit }, data) => {
    commit('JOIN_REQUEST', data.id)
    return api.rejoin(data).then(response => {
      return store.dispatch('pfqueue/pollTaskStatus', response.task_id).then(response => {
        commit('JOIN_SUCCESS', { id: data.id, response })
        return state.joins[data.id]
      })
    }).catch(error => {
      commit('JOIN_ERROR', { id: data.id, response: error })
      return state.joins[data.id]
    })
  },
  unjoinDomain: ({ state, commit }, data) => {
    commit('UNJOIN_REQUEST', data.id)
    return api.unjoin(data).then(response => {
      return store.dispatch('pfqueue/pollTaskStatus', response.task_id).then(response => {
        commit('UNJOIN_SUCCESS', { id: data.id, response })
        return state.joins[data.id]
      })
    }).catch(error => {
      commit('UNJOIN_ERROR', { id: data.id, response: error })
      return state.joins[data.id]
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
    if (data.id in state.joins) {
      Vue.delete(state.joins, data.id) // clear cache
      store.dispatch('$_domains/testDomain', data.id) // refresh cache
    }
  },
  ITEM_DESTROYED: (state, id) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, id, null)
    Vue.delete(state.joins, id)
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
  TEST_REQUEST: (state, id) => {
    if (!(id in state.joins)) {
      Vue.set(state.joins, id, {})
    }
    Vue.set(state.joins[id], 'status', null)
  },
  TEST_SUCCESS: (state, data) => {
    Vue.set(state.joins[data.id], 'status', true)
    Vue.set(state.joins[data.id], 'message', data.response.message)
  },
  TEST_ERROR: (state, data) => {
    Vue.set(state.joins[data.id], 'status', false)
    const { error: { response: { data: { message = null } = {} } = {} } = {} } = data
    Vue.set(state.joins[data.id], 'message', message || data.error.message)
  },
  JOIN_REQUEST: (state, id) => {
    if (!(id in state.joins)) {
      Vue.set(state.joins, id, {})
    }
    Vue.set(state.joins[id], 'status', null)
    Vue.set(state.joins[id], 'message', null)
  },
  JOIN_SUCCESS: (state, data) => {
    Vue.set(state.joins[data.id], 'status', true)
    Vue.set(state.joins[data.id], 'message', data.response.message)
    Vue.set(state, 'joins', { [data.id]: state.joins[data.id] }) // clear other cache
  },
  JOIN_ERROR: (state, data) => {
    Vue.set(state.joins[data.id], 'status', false)
    Vue.set(state.joins[data.id], 'message', data.response.message)
  },
  UNJOIN_REQUEST: (state, id) => {
    if (!(id in state.joins)) {
      Vue.set(state.joins, id, {})
    }
    Vue.set(state.joins[id], 'status', null)
    Vue.set(state.joins[id], 'message', null)
  },
  UNJOIN_SUCCESS: (state, data) => {
    Vue.set(state.joins[data.id], 'status', false)
    Vue.set(state.joins[data.id], 'message', data.response.message)
    Vue.set(state, 'joins', { [data.id]: state.joins[data.id] }) // clear other cache
  },
  UNJOIN_ERROR: (state, data) => {
    Vue.set(state.joins[data.id], 'status', true)
    Vue.set(state.joins[data.id], 'message', data.response.message)
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
