/**
* "$_roles" store module
*/
import Vue from 'vue'
import api from './_api'

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  REASSIGNING: 'reassigning',
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
  isWaiting: state => [types.LOADING, types.DELETING, types.REASSIGNING].includes(state.itemStatus),
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
  getRole: ({ state, commit }, id) => {
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
  createRole: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.create(data).then(response => {
      commit('ITEM_REPLACED', data)
      commit('config/ROLES_UPDATED', false, { root: true })
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateRole: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.update(data).then(response => {
      commit('ITEM_REPLACED', data)
      commit('config/ROLES_UPDATED', false, { root: true })
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteRole: ({ commit }, data) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.delete(data).then(response => {
      commit('ITEM_DESTROYED', data)
      commit('config/ROLES_UPDATED', false, { root: true })
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  reassignRole: ({ commit }, data) => {
    commit('ITEM_REQUEST', types.REASSIGNING)
    return api.reassign(data).then(response => {
      commit('ITEM_DESTROYED', data.from)
      commit('config/ROLES_UPDATED', false, { root: true })
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
