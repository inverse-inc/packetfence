/**
* "$_security_events" store module
*/
import Vue from 'vue'
import bytes from '@/utils/bytes'
import api from '../_api'
import {
  triggerCategories,
  triggerFields
} from '../_config/securityEvent'

const decomposeTriggers = (triggers) => {
  return (triggers || []).map(trigger => {
    let decomposed = { endpoint: { conditions: [] }, profiling: { conditions: [] }, usage: {}, event: {} }
    for (const type in trigger) {
      const { [type]: value } = trigger
      if (value && value.length) {
        if (type in triggerFields) {
          let { [type]: { category } = {} } = triggerFields
          let condition = { typeValue: { type, value } }
          if ('conditions' in decomposed[category]) {
            decomposed[category].conditions.push({ type, value }) // 'endpoint' or 'profiling'
          } else {
            decomposed[category] = { typeValue: { type, value } } // 'usage' or 'event'
          }
          if (category === triggerCategories.USAGE) {
            // Decompose data usage
            const { groups } = value.match(/(?<direction>TOT|IN|OUT)(?<limit>[0-9]+)(?<multiplier>[KMG]?)B(?<interval>[DWMY])/)
            if (groups) {
              decomposed[category].direction = groups.direction
              decomposed[category].limit = groups.limit * Math.pow(1024, 'KMG'.indexOf(groups.multiplier) + 1)
              decomposed[category].interval = groups.interval
            }
          }
        } else {
          throw new Error(`Uncategorized field type: ${type}`)
        }
      }
    }
    return decomposed
  })
}

const recomposeTriggers = (triggers) => {
  return (triggers || []).map(trigger => {
    let recomposed = Object.keys(triggerFields).reduce((a, v) => {
      return { ...a, ...{ [v]: null } }
    }, {})
    for (var category in trigger) {
      if ([triggerCategories.ENDPOINT, triggerCategories.PROFILING].includes(category)) { // 'endpoint' or 'profiling'
        const { [category]: { conditions = [] } = {} } = trigger
        for (const condition of conditions) {
          const { type, value } = condition || {}
          if (type && value) {
            const { value: nestedValue } = value || {}
            if (nestedValue) {
              recomposed[type] = nestedValue
            } else {
              recomposed[type] = value
            }
          }
        }
      }
      if ([triggerCategories.USAGE, triggerCategories.EVENT].includes(category)) { // 'usage' or 'event'
        if (category === triggerCategories.USAGE) { // normalize 'usage'
          const { [category]: { direction, limit, interval } = {} } = trigger
          trigger[triggerCategories.USAGE]['typeValue'] = {
            type: 'accounting',
            value: (direction && limit && interval)
              ? `${direction}${bytes.toHuman(limit, 0, true).replace(/ /, '').toUpperCase()}B${interval}`
              : null
          }
        }
        const { [category]: { typeValue: { type, value } = {} } = {} } = trigger
        if (type && value) {
          recomposed[type] = value
        }
      }
    }
    return recomposed
  })
}

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
      fields: ['id'].join(',')
    }
    return api.securityEvents(params).then(response => {
      return response.items
    })
  },
  options: ({ commit }, id) => {
    commit('ITEM_REQUEST')
    if (id) {
      return api.securityEventOptions(id).then(response => {
        commit('ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    } else {
      return api.securityEventsOptions().then(response => {
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
    return api.securityEvent(id).then(item => {
      if ('triggers' in item) { // decompose security event triggers
        item.triggers = decomposeTriggers(item.triggers)
      }
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
      data.triggers = recomposeTriggers(data.triggers)
    }
    return api.createSecurityEvent(data).then(response => {
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
      data.triggers = recomposeTriggers(data.triggers)
    }
    return api.updateSecurityEvent(data).then(response => {
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
    return api.updateSecurityEvent(_data).then(response => {
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
    return api.updateSecurityEvent(_data).then(response => {
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
    return api.deleteSecurityEvent(data).then(response => {
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
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
