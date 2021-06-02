import Vue from 'vue'
import api from './_api'

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
export const state = () => {
  return {
    macVendors: {
      cache: {},
      message: '',
      status: ''
    }
  }
}

export const getters = {
  isMacVendorsWaiting: state => [types.LOADING, types.DELETING].includes(state.macVendors.status),
  isMacVendorsLoading: state => state.macVendors.status === types.LOADING
}

export const actions = {
  macVendors: () => {
    const params = {
      sort: 'id',
      fields: ['id'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  getMacVendor: ({ state, commit }, id) => {
    if (state.macVendors.cache[id]) {
      return Promise.resolve(state.macVendors.cache[id])
    }
    commit('MAC_VENDOR_REQUEST')
    return api.item(id).then(item => {
      commit('MAC_VENDOR_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch(err => {
      commit('MAC_VENDOR_ERROR', err.response)
      throw err
    })
  },
  createMacVendor: ({ commit }, data) => {
    commit('MAC_VENDOR_REQUEST')
    return api.create(data).then(response => {
      data.id = response.id
      commit('MAC_VENDOR_REPLACED', data)
      return response
    }).catch(err => {
      commit('MAC_VENDOR_ERROR', err.response)
      throw err
    })
  },
  updateMacVendor: ({ commit }, data) => {
    commit('MAC_VENDOR_REQUEST')
    return api.update(data).then(response => {
      commit('MAC_VENDOR_REPLACED', data)
      return response
    }).catch(err => {
      commit('MAC_VENDOR_ERROR', err.response)
      throw err
    })
  },
  deleteMacVendor: ({ commit }, data) => {
    commit('MAC_VENDOR_REQUEST', types.DELETING)
    return api.delete(data).then(response => {
      commit('MAC_VENDOR_DESTROYED', data)
      return response
    }).catch(err => {
      commit('MAC_VENDOR_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  MAC_VENDOR_REQUEST: (state, type) => {
    state.macVendors.status = type || types.LOADING
    state.macVendors.message = ''
  },
  MAC_VENDOR_REPLACED: (state, data) => {
    state.macVendors.status = types.SUCCESS
    Vue.set(state.macVendors.cache, data.id, data)
  },
  MAC_VENDOR_DESTROYED: (state, id) => {
    state.macVendors.status = types.SUCCESS
    Vue.set(state.macVendors.cache, id, null)
  },
  MAC_VENDOR_ERROR: (state, response) => {
    state.macVendors.status = types.ERROR
    if (response && response.data) {
      state.macVendors.message = response.data.message
    }
  }
}
