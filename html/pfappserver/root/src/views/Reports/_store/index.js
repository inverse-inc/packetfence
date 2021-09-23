/**
* "$_reports" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import api from '../_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_reports/isLoading']),
    getList: () => $store.dispatch('$_reports/all'),
    getListOptions: () => $store.dispatch('$_reports/options'),
    getItem: params => $store.dispatch('$_reports/getReport', params.id),
    getItemOptions: params => $store.dispatch('$_reports/options', params.id)
  }
}

const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const state = () => {
  return {
    cache: {}, // reports details
    status: '',
    message: ''
  }
}

const getters = {
  isLoading: state => state.status === types.LOADING
}

const actions = {
  all: () => {
    const params = {
      sort: ['id'],
      fields: ['id', 'description', 'long_description', 'type']
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
  getReport: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id])
    }
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.item(id).then(response => {
        commit('ITEM_REPLACED', response)
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
    })
  },
  searchReport: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return new Promise((resolve, reject) => {
      api.search(data).then(response => {
        commit('ITEM_SUCCESS')
        resolve(response)
      }).catch(err => {
        commit('ITEM_ERROR', err.response)
        reject(err)
      })
    })
  }
}

const mutations = {
  ITEM_REQUEST: (state) => {
    state.status = types.LOADING
    state.message = ''
  },
  ITEM_REPLACED: (state, data) => {
    state.status = types.SUCCESS
    Vue.set(state.cache, data.id, data)
  },
  ITEM_SUCCESS: (state) => {
    state.status = types.SUCCESS
  },
  ITEM_ERROR: (state, response) => {
    state.status = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
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
