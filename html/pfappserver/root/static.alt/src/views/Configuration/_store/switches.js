/**
* "$_switches" store module
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
const state = {
  cache: {}, // items details
  message: '',
  itemStatus: ''
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.itemStatus),
  isLoading: state => state.itemStatus === types.LOADING
}

const actions = {
  all: () => {
    const params = {
      sort: 'id',
      fields: ['id', 'description', 'class'].join(',')
    }
    return api.switches(params).then(response => {
      return response.items
    })
  },
  optionsById: ({ commit }, id) => {
    commit('ITEM_REQUEST')
    return api.switchOptions(id).then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsBySwitchGroup: ({ commit }, switchGroup) => {
    commit('ITEM_REQUEST')
    return api.switchesOptions(switchGroup).then(response => {
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
    return api.switche(id).then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createSwitch: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.createSwitch(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateSwitch: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.updateSwitch(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteSwitch: ({ commit }, data) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.deleteSwitch(data).then(response => {
      commit('ITEM_DESTROYED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  invalidateSwitchCache: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.invalidateSwitchCache(data).then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
  },
  bulkImport: ({ commit }, data) => {
    let hasError = false
    const {
      ignoreInsertIfNotExists,
      ignoreUpdateIfExists,
      stopOnFirstError,
      items: _items
    } = data
    const bulkImport = async (_items) => {
      let items = []
      for (let i = 0; i < _items.length; i++) {
        const { [i]: item = {} } = _items
        const { id } = item
        if (stopOnFirstError && hasError) {
          items[i] = { item, message: 'Skipped', status: 424 }
        } else {
          items[i] = await new Promise((resolve) => {
            api.switcheQuiet(id).then(() => {
              // exists
              if (ignoreUpdateIfExists) {
                resolve({ item, isNew: false, message: 'Skip already exists', status: 409 })
              } else {
                api.updateSwitch({ ...item, ...{ quiet: true } }).then(response => {
                  resolve({ item, isNew: false, status: 200 })
                }).catch(err => {
                  if (stopOnFirstError) hasError = true // exit
                  const { response: { data: { message: error } = {} } = {} } = err
                  resolve({ item, errors: [ error ], message: 'Cannot import switch', status: 422 })
                })
              }
            }).catch(() => {
              // not exists
              if (ignoreInsertIfNotExists) {
                resolve({ item, isNew: true, message: 'Skip does not exists', status: 404 })
              } else {
                api.createSwitch({ ...item, ...{ quiet: true } }).then(response => {
                  resolve({ item, isNew: true, status: 200 })
                }).catch(err => {
                  if (stopOnFirstError) hasError = true // exit
                  const { response: { data: { message: error } = {} } = {} } = err
                  resolve({ item, errors: [ error ], message: 'Cannot import switch', status: 422 })
                })
              }
            })
          })
        }
      }
      return items
    }
    return bulkImport(_items).then((items) => {
      return items
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
