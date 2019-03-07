/**
* "$_bases" store module
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
  all: ({ commit }) => {
    const params = {
      sort: 'id',
      fields: ['id'].join(',')
    }
    return api.bases(params).then(response => {
      response.items.forEach((item) => {
        commit('ITEM_REPLACED', item)
      })
      return response.items
    })
  },
  getBase: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id])
    }
    commit('ITEM_REQUEST')
    return api.base(id).then(item => {
      if (id === 'general') {
        // build `fqdn` from `hostname` and `domain`
        item.fqdn = ((item.hostname) ? item.hostname + '.' : '') + item.domain
      }
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getActiveActive: ({ state, commit }) => {
    if (state.cache['active_active']) {
      return Promise.resolve(state.cache['active_active'])
    }
    commit('ITEM_REQUEST')
    return api.base('active_active').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsActiveActive: () => {
    return api.baseOptions('active_active').then(response => {
      return response
    })
  },
  updateActiveActive: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'active_active'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getAdvanced: ({ state, commit }) => {
    if (state.cache['advanced']) {
      return Promise.resolve(state.cache['advanced'])
    }
    commit('ITEM_REQUEST')
    return api.base('advanced').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsAdvanced: () => {
    return api.baseOptions('advanced').then(response => {
      return response
    })
  },
  updateAdvanced: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'advanced'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getAlerting: ({ state, commit }) => {
    if (state.cache['alerting']) {
      return Promise.resolve(state.cache['alerting'])
    }
    commit('ITEM_REQUEST')
    return api.base('alerting').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsAlerting: () => {
    return api.baseOptions('alerting').then(response => {
      return response
    })
  },
  updateAlerting: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'alerting'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getCaptivePortal: ({ state, commit }) => {
    if (state.cache['captive_portal']) {
      return Promise.resolve(state.cache['captive_portal'])
    }
    commit('ITEM_REQUEST')
    return api.base('captive_portal').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsCaptivePortal: () => {
    return api.baseOptions('captive_portal').then(response => {
      return response
    })
  },
  updateCaptivePortal: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'captive_portal'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getDatabase: ({ state, commit }) => {
    if (state.cache['database']) {
      return Promise.resolve(state.cache['database'])
    }
    commit('ITEM_REQUEST')
    return api.base('database').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsDatabase: () => {
    return api.baseOptions('database').then(response => {
      return response
    })
  },
  updateDatabase: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'database'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getDatabaseAdvanced: ({ state, commit }) => {
    if (state.cache['database_advanced']) {
      return Promise.resolve(state.cache['database_advanced'])
    }
    commit('ITEM_REQUEST')
    return api.base('database_advanced').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsDatabaseAdvanced: () => {
    return api.baseOptions('database_advanced').then(response => {
      return response
    })
  },
  updateDatabaseAdvanced: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'database_advanced'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getDatabaseEncryption: ({ state, commit }) => {
    if (state.cache['database_encryption']) {
      return Promise.resolve(state.cache['database_encryption'])
    }
    commit('ITEM_REQUEST')
    return api.base('database_encryption').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsDatabaseEncryption: () => {
    return api.baseOptions('database_encryption').then(response => {
      return response
    })
  },
  updateDatabaseEncryption: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'database_encryption'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getFencing: ({ state, commit }) => {
    if (state.cache['fencing']) {
      return Promise.resolve(state.cache['fencing'])
    }
    commit('ITEM_REQUEST')
    return api.base('fencing').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsFencing: () => {
    return api.baseOptions('fencing').then(response => {
      return response
    })
  },
  updateFencing: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'fencing'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getFingerbankDeviceChange: ({ state, commit }) => {
    if (state.cache['fingerbank_device_change']) {
      return Promise.resolve(state.cache['fingerbank_device_change'])
    }
    commit('ITEM_REQUEST')
    return api.base('fingerbank_device_change').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsFingerbankDeviceChange: () => {
    return api.baseOptions('fingerbank_device_change').then(response => {
      return response
    })
  },
  updateFingerbankDeviceChange: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'fingerbank_device_change'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getGeneral: ({ state, commit }) => {
    if (state.cache['general']) {
      return Promise.resolve(state.cache['general'])
    }
    commit('ITEM_REQUEST')
    return api.base('general').then(item => {
      // build `fqdn` from `hostname` and `domain`
      item.fqdn = ((item.hostname) ? item.hostname + '.' : '') + item.domain
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsGeneral: () => {
    return api.baseOptions('general').then(response => {
      return response
    })
  },
  updateGeneral: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'general'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getGuestsAdminRegistration: ({ state, commit }) => {
    if (state.cache['guests_admin_registration']) {
      return Promise.resolve(state.cache['guests_admin_registration'])
    }
    commit('ITEM_REQUEST')
    return api.base('guests_admin_registration').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsGuestsAdminRegistration: () => {
    return api.baseOptions('guests_admin_registration').then(response => {
      return response
    })
  },
  updateGuestsAdminRegistration: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'guests_admin_registration'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getInline: ({ state, commit }) => {
    if (state.cache['inline']) {
      return Promise.resolve(state.cache['inline'])
    }
    commit('ITEM_REQUEST')
    return api.base('inline').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsInline: () => {
    return api.baseOptions('inline').then(response => {
      return response
    })
  },
  updateInline: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'inline'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getMseTab: ({ state, commit }) => {
    if (state.cache['mse_tab']) {
      return Promise.resolve(state.cache['mse_tab'])
    }
    commit('ITEM_REQUEST')
    return api.base('mse_tab').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsMseTab: () => {
    return api.baseOptions('mse_tab').then(response => {
      return response
    })
  },
  updateMseTab: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'mse_tab'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getNetwork: ({ state, commit }) => {
    if (state.cache['network']) {
      return Promise.resolve(state.cache['network'])
    }
    commit('ITEM_REQUEST')
    return api.base('network').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsNetwork: () => {
    return api.baseOptions('network').then(response => {
      return response
    })
  },
  updateNetwork: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'network'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getNodeImport: ({ state, commit }) => {
    if (state.cache['node_import']) {
      return Promise.resolve(state.cache['node_import'])
    }
    commit('ITEM_REQUEST')
    return api.base('node_import').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsNodeImport: () => {
    return api.baseOptions('node_import').then(response => {
      return response
    })
  },
  updateNodeImport: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'node_import'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getParking: ({ state, commit }) => {
    if (state.cache['parking']) {
      return Promise.resolve(state.cache['parking'])
    }
    commit('ITEM_REQUEST')
    return api.base('parking').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsParking: () => {
    return api.baseOptions('parking').then(response => {
      return response
    })
  },
  updateParking: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'parking'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getPFDHCP: ({ state, commit }) => {
    if (state.cache['pfdhcp']) {
      return Promise.resolve(state.cache['pf_dhcp'])
    }
    commit('ITEM_REQUEST')
    return api.base('pf_dhcp').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsPFDHCP: () => {
    return api.baseOptions('pf_dhcp').then(response => {
      return response
    })
  },
  updatePFDHCP: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'pfdhcp'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getPorts: ({ state, commit }) => {
    if (state.cache['ports']) {
      return Promise.resolve(state.cache['ports'])
    }
    commit('ITEM_REQUEST')
    return api.base('ports').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsPorts: () => {
    return api.baseOptions('ports').then(response => {
      return response
    })
  },
  updatePorts: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'ports'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getProvisioning: ({ state, commit }) => {
    if (state.cache['provisioning']) {
      return Promise.resolve(state.cache['provisioning'])
    }
    commit('ITEM_REQUEST')
    return api.base('provisioning').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsProvisioning: () => {
    return api.baseOptions('provisioning').then(response => {
      return response
    })
  },
  updateProvisioning: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'provisioning'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getRadiusConfiguration: ({ state, commit }) => {
    if (state.cache['radius_configuration']) {
      return Promise.resolve(state.cache['radius_configuration'])
    }
    commit('ITEM_REQUEST')
    return api.base('radius_configuration').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsRadiusConfiguration: () => {
    return api.baseOptions('radius_configuration').then(response => {
      return response
    })
  },
  updateRadiusConfiguration: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'radius_configuration'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getServices: ({ state, commit }) => {
    if (state.cache['services']) {
      return Promise.resolve(state.cache['services'])
    }
    commit('ITEM_REQUEST')
    return api.base('services').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsServices: () => {
    return api.baseOptions('services').then(response => {
      return response
    })
  },
  updateServices: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'services'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getSNMPTraps: ({ state, commit }) => {
    if (state.cache['snmp_traps']) {
      return Promise.resolve(state.cache['snmp_traps'])
    }
    commit('ITEM_REQUEST')
    return api.base('snmp_traps').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsSNMPTraps: () => {
    return api.baseOptions('snmp_traps').then(response => {
      return response
    })
  },
  updateSNMPTraps: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'snmp_traps'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getWebServices: ({ state, commit }) => {
    if (state.cache['webservices']) {
      return Promise.resolve(state.cache['webservices'])
    }
    commit('ITEM_REQUEST')
    return api.base('webservices').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsWebServices: () => {
    return api.baseOptions('webservices').then(response => {
      return response
    })
  },
  updateWebServices: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'webservices'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
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
  ITEM_ERROR: (state, response) => {
    state.itemStatus = types.ERROR
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
