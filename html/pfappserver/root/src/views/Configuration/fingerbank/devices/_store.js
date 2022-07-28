import Vue from 'vue'
import { computed } from '@vue/composition-api'
import { types } from '@/store'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_fingerbank/isDevicesLoading']),
    createItem: params => $store.dispatch('$_fingerbank/createDevice', params),
    getItem: params => $store.dispatch('$_fingerbank/getDevice', params.id),
    updateItem: params => $store.dispatch('$_fingerbank/updateDevice', params),
    deleteItem: params => $store.dispatch('$_fingerbank/deleteDevice', params.id),
  }
}

// Default values
export const state = () => {
  return {
    devices: {
      cache: {},
      classes: [],
      message: '',
      status: ''
    }
  }
}

export const getters = {
  isDevicesWaiting: state => [types.LOADING, types.DELETING].includes(state.devices.status),
  isDevicesLoading: state => state.devices.status === types.LOADING,
  assocClassesById: state => state.classes.reduce((assoc, { id, name }) => {
    return { ...assoc, [id]: name }
  }, {}),
  assocClassesByName: state => state.classes.reduce((assoc, { id, name }) => {
    return { ...assoc, [name]: id }
  }, {}),

}

export const actions = {
  devices: () => {
    const params = {
      sort: 'id',
      fields: ['id', 'name'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  getClasses: ({ state, commit }) => {
    commit('DEVICE_REQUEST')
    return api.classes().then(response => {
      commit('DEVICE_CLASSES', response.items)
      return state.classes
    }).catch(err => {
      commit('DEVICE_ERROR', err.response)
      throw err
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
  deleteDevice: ({ commit }, id) => {
    commit('DEVICE_REQUEST', types.DELETING)
    return api.delete(id).then(response => {
      commit('DEVICE_DESTROYED', id)
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
  },
  DEVICE_CLASSES: (state, classes) => {
    state.devices.status = types.SUCCESS
    state.classes = classes
  }
}
