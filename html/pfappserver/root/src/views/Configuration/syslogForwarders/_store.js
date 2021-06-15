/**
* "$_syslog_forwarders" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_syslog_forwarders/isLoading']),
    getList: () => $store.dispatch('$_syslog_forwarders/all'),
    getListOptions: params => $store.dispatch('$_syslog_forwarders/optionsBySyslogForwarderType', params.syslogForwarderType),
    createItem: params => $store.dispatch('$_syslog_forwarders/createSyslogForwarder', params),
    getItem: params => $store.dispatch('$_syslog_forwarders/getSyslogForwarder', params.id).then(item => {
      return (params.isClone)
        ? { ...item, id: `${item.id}-copy`, not_deletable: false }
        : item
    }),
    getItemOptions: params => $store.dispatch('$_syslog_forwarders/optionsById', params.id),
    updateItem: params => $store.dispatch('$_syslog_forwarders/updateSyslogForwarder', params),
    deleteItem: params => $store.dispatch('$_syslog_forwarders/deleteSyslogForwarder', params.id),
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
      fields: ['id', 'type'].join(',')
    }
    return api.syslogForwarders(params).then(response => {
      return response.items
    })
  },
  optionsById: ({ commit }, id) => {
    commit('ITEM_REQUEST')
    return api.syslogForwarderOptions(id).then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsBySyslogForwarderType: ({ commit }, syslogForwarderType) => {
    commit('ITEM_REQUEST')
    return api.syslogForwardersOptions(syslogForwarderType).then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getSyslogForwarder: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id]).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.syslogForwarder(id).then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createSyslogForwarder: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.createSyslogForwarder(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateSyslogForwarder: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.updateSyslogForwarder(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteSyslogForwarder: ({ commit }, data) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.deleteSyslogForwarder(data).then(response => {
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
