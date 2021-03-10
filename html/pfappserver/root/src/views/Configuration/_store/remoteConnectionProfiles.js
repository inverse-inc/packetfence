/**
* "$_remote_connection_profiles" store module
*/
import Vue from 'vue'
import api from '../_api'

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
    files: {
      message: '',
      status: '',
      cache: {}
    }
  }
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.itemStatus),
  isLoading: state => state.itemStatus === types.LOADING,
  isWaitingFiles: state => [types.LOADING, types.DELETING].includes(state.files.tatus),
  isLoadingFiles: state => state.files.status === types.LOADING
}

const actions = {
  all: () => {
    const params = {
      sort: 'id',
      fields: ['id'].join(',')
    }
    return api.remoteConnectionProfiles(params).then(response => {
      return response.items
    })
  },
  options: ({ commit }, id) => {
    commit('ITEM_REQUEST')
    if (id) {
      return api.remoteConnectionProfileOptions(id).then(response => {
        commit('ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    } else {
      return api.remoteConnectionProfilesOptions().then(response => {
        commit('ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    }
  },
  getRemoteConnectionProfile: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id]).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.remoteConnectionProfile(id).then(item => {
      commit('ITEM_REPLACED', item)
      return state.cache[id]
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createRemoteConnectionProfile: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.createRemoteConnectionProfile(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateRemoteConnectionProfile: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.updateRemoteConnectionProfile(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteRemoteConnectionProfile: ({ commit }, data) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.deleteRemoteConnectionProfile(data).then(response => {
      commit('ITEM_DESTROYED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  sortRemoteConnectionProfiles: ({ commit }, data) => {
    const params = {
      items: data
    }
    commit('ITEM_REQUEST', types.LOADING)
    return api.sortRemoteConnectionProfiles(params).then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  enableRemoteConnectionProfile: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    const _data = { id: data.id, status: 'enabled' }
    return api.updateRemoteConnectionProfile(_data).then(response => {
      commit('ITEM_ENABLED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  disableRemoteConnectionProfile: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    const _data = { id: data.id, status: 'disabled' }
    return api.updateRemoteConnectionProfile(_data).then(response => {
      commit('ITEM_DISABLED', data)
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
    Vue.set(state.cache, data.id, data)
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
  },
  FILE_REQUEST: (state, type) => {
    state.files.status = type || types.LOADING
    state.files.message = ''
  },
  FILE_SUCCESS: (state) => {
    state.files.status = types.SUCCESS
  },
  FILE_REPLACED: (state, data) => {
    state.files.status = types.SUCCESS
    Vue.set(state.files.cache, data.id, data.files)
  },
  FILE_DESTROYED: (state) => {
    state.files.status = types.SUCCESS
  },
  FILE_ERROR: (state, response) => {
    state.files.status = types.ERROR
    if (response && response.data) {
      state.files.message = response.data.message
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
