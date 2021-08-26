/**
* "$_security_events" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from './_api'
import {
  decomposeTriggers,
  recomposeTriggers
} from '../securityEvents/config'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_security_events/isLoading']),
    getList: () => $store.dispatch('$_security_events/all'),
    getListOptions: () => $store.dispatch('$_security_events/options'),
    createItem: params => $store.dispatch('$_security_events/createSecurityEvent', params),
    getItem: params => $store.dispatch('$_security_events/getSecurityEvent', params.id).then(item => {
      return (params.isClone)
        ? { ...item, id: `${item.id}-${i18n.t('copy')}`, not_deletable: false }
        : item
    }),
    getItemOptions: params => $store.dispatch('$_security_events/options', params.id),
    updateItem: params => $store.dispatch('$_security_events/updateSecurityEvent', params),
    deleteItem: params => $store.dispatch('$_security_events/deleteSecurityEvent', params.id),
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
      fields: ['id'].join(',')
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
  getSecurityEvent: ({ state, commit }, id) => {
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
  createSecurityEvent: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    if ('triggers' in data) { // recompose security event triggers
      data = JSON.parse(JSON.stringify(data)) // dereference
      data.triggers = recomposeTriggers(data.triggers)
    }
    return api.create(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateSecurityEvent: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    if ('triggers' in data) { // recompose security event triggers
      data = JSON.parse(JSON.stringify(data)) // dereference
      data.triggers = recomposeTriggers(data.triggers)
    }
    return api.update(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  enableSecurityEvent: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    const { id, quiet = false } = data
    const _data = { id, enabled: 'Y', quiet }
    return api.update(_data).then(response => {
      commit('ITEM_ENABLED', _data)
      commit('$_config_security_events_searchable/ITEM_UPDATED', { key: 'id', id, prop: 'enabled', data: 'Y' }, { root: true })
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  disableSecurityEvent: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    const { id, quiet = false } = data
    const _data = { id, enabled: 'N', quiet }
    return api.update(_data).then(response => {
      commit('ITEM_DISABLED', _data)
      commit('$_config_security_events_searchable/ITEM_UPDATED', { key: 'id', id, prop: 'enabled', data: 'N' }, { root: true })
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteSecurityEvent: ({ commit }, data) => {
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
    let dataCopy = JSON.parse(JSON.stringify(data))
    if ('triggers' in dataCopy) { // decompose security event triggers
      dataCopy.triggers = decomposeTriggers(dataCopy.triggers)
    }
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, data.id, dataCopy)
  },
  ITEM_ENABLED: (state, data) => {
    state.itemStatus = types.SUCCESS
    if (data.id in state.cache) {
      Vue.set(state.cache, data.id, { ...state.cache[data.id], ...data })
    }
  },
  ITEM_DISABLED: (state, data) => {
    state.itemStatus = types.SUCCESS
    if (data.id in state.cache) {
      Vue.set(state.cache, data.id, { ...state.cache[data.id], ...data })
    }
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
