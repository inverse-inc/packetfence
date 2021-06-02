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
    devices: {
      cache: {},
      message: '',
      status: ''
    }
  }
}

export const getters = {
  isDevicesWaiting: state => [types.LOADING, types.DELETING].includes(state.devices.status),
  isDevicesLoading: state => state.devices.status === types.LOADING
}

export const actions = {
  devices: () => {
    const params = {
      sort: 'id',
      fields: ['id'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  getDevice: ({ state, commit }, id) => {
    if (state.devices.cache[id]) {
      return Promise.resolve(state.devices.cache[id])
    }
    commit('DEVICE_REQUEST')
    return api.item(id).then(item => {
      commit('DEVICE_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch(err => {
      commit('DEVICE_ERROR', err.response)
      throw err
    })
  },
  createDevice: ({ commit }, data) => {
    commit('DEVICE_REQUEST')
    return api.create(data).then(response => {
      data.id = response.id
      commit('DEVICE_REPLACED', data)
      return response
    }).catch(err => {
      commit('DEVICE_ERROR', err.response)
      throw err
    })
  },
  updateDevice: ({ commit }, data) => {
    commit('DEVICE_REQUEST')
    return api.update(data).then(response => {
      commit('DEVICE_REPLACED', data)
      return response
    }).catch(err => {
      commit('DEVICE_ERROR', err.response)
      throw err
    })
  },
  deleteDevice: ({ commit }, data) => {
    commit('DEVICE_REQUEST', types.DELETING)
    return api.delete(data).then(response => {
      commit('DEVICE_DESTROYED', data)
      return response
    }).catch(err => {
      commit('DEVICE_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  DEVICE_REQUEST: (state, type) => {
    state.devices.status = type || types.LOADING
    state.devices.message = ''
  },
  DEVICE_REPLACED: (state, data) => {
    state.devices.status = types.SUCCESS
    Vue.set(state.devices.cache, data.id, data)
  },
  DEVICE_DESTROYED: (state, id) => {
    state.devices.status = types.SUCCESS
    Vue.set(state.devices.cache, id, null)
  },
  DEVICE_ERROR: (state, response) => {
    state.devices.status = types.ERROR
    if (response && response.data) {
      state.devices.message = response.data.message
    }
  }
}
