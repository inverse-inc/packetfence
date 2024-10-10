/**
* "$_switches" store module
*/
import Vue from 'vue'
import store, { types } from '@/store'
import { computed } from '@vue/composition-api'
import api from './_api'
import { baseRoles } from './config'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_switches/isLoading']),
    getList: () => $store.dispatch('$_switches/all'),
    getListOptions: params => $store.dispatch('$_switches/optionsBySwitchGroup', params.switchGroup),
    createItem: params => $store.dispatch('$_switches/createSwitch', params),
    getItem: params => $store.dispatch('$_switches/getSwitch', params.id),
    getItemOptions: params => $store.dispatch('$_switches/optionsById', params.id),
    updateItem: params => $store.dispatch('$_switches/updateSwitch', params),
    deleteItem: params => $store.dispatch('$_switches/deleteSwitch', params.id),
    precreateItemAcls: params => $store.dispatch('$_switches/precreateAcls', params.id),
  }
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
  all: ({ commit }) => {
    commit('ITEM_REQUEST')
    const params = {
      sort: 'id',
      fields: ['id', 'description', 'class'].join(',')
    }
    return api.list(params).then(response => {
      commit('ITEM_SUCCESS')
      return response.items
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  allPushACLs: ({ commit }) => {
    commit('ITEM_REQUEST')
    const body = {
      fields: ['id', 'UsePushACLs'],
      query: { op: 'and', values: [ { op: 'or', values: [ { field: 'UsePushACLs', op: 'equals', value: 'Y' } ] } ] },
      sort: ['id'],
      limit: 1000
    }
    return api.search(body).then(response => {
      commit('ITEM_SUCCESS')
      const { items = [] } = response
      return items.map(item => item.id)
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsById: ({ commit }, id) => {
    commit('ITEM_REQUEST')
    return api.itemOptions(id).then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsBySwitchGroup: ({ commit }, switchGroup) => {
    commit('ITEM_REQUEST')
    return api.listOptions(switchGroup).then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getSwitch: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id]).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.item(id).then(item => {
      // pre-declare role mappings, fixes #6721
      return store.dispatch('$_roles/all').then(roles => {
        roles = [
          ...baseRoles,
          ...roles.map(role => role.id)
        ]
        roles
          .forEach(role => {
            item = {
              [`${role}Vlan`]: null,
              [`${role}Role`]: null,
              [`${role}AccessList`]: null,
              [`${role}Url`]: null,
              ...item
            }
          })
        commit('ITEM_REPLACED', item)
        return JSON.parse(JSON.stringify(state.cache[id]))
      })
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createSwitch: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.create(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateSwitch: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.update(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteSwitch: ({ commit }, id) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.delete(id).then(response => {
      commit('ITEM_DESTROYED', id)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  invalidateSwitchCache: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.invalidateCache(data).then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  bulkImportAsync: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.bulkImportAsync(data).then(response => {
      const { data: { task_id } = {} } = response
      return store.dispatch('pfqueue/pollTaskStatus', { task_id }).then(response => {
        commit('ITEM_BULK_SUCCESS', response.items)
        return response
      })
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
    })
  },
  precreateAcls: ({ commit }, id) => {
    commit('ITEM_REQUEST')
    return api.precreateAcls(id).then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
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
  ITEM_BULK_SUCCESS: (state, response) => {
    state.itemStatus = 'success'
    response.forEach(item => {
      if (item.status === 200 && item.item.id in state.cache) {
        Vue.set(state.cache, item.item.id, null)
      }
    })
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
