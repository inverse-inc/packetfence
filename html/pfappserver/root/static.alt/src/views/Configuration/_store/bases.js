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
      return Promise.resolve(state.cache[id]).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base(id).then(item => {
      if (id === 'general') {
        // build `fqdn` from `hostname` and `domain`
        item.fqdn = ((item.hostname) ? item.hostname + '.' : '') + item.domain
      }
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getActiveActive: ({ state, commit }) => {
    if (state.cache['active_active']) {
      return Promise.resolve(state.cache['active_active']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('active_active').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsActiveActive: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('active_active').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['advanced']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('advanced').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsAdvanced: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('advanced').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['alerting']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('alerting').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsAlerting: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('alerting').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['captive_portal']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('captive_portal').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsCaptivePortal: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('captive_portal').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['database']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('database').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsDatabase: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('database').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['database_advanced']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('database_advanced').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsDatabaseAdvanced: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('database_advanced').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['database_encryption']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('database_encryption').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsDatabaseEncryption: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('database_encryption').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['fencing']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('fencing').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsFencing: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('fencing').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['fingerbank_device_change']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('fingerbank_device_change').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsFingerbankDeviceChange: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('fingerbank_device_change').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['general']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('general').then(item => {
      // build `fqdn` from `hostname` and `domain`
      item.fqdn = ((item.hostname) ? item.hostname + '.' : '') + item.domain
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsGeneral: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('general').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['guests_admin_registration']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('guests_admin_registration').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsGuestsAdminRegistration: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('guests_admin_registration').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['inline']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('inline').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsInline: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('inline').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['mse_tab']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('mse_tab').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsMseTab: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('mse_tab').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['network']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('network').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsNetwork: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('network').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['node_import']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('node_import').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsNodeImport: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('node_import').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['parking']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('parking').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsParking: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('parking').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['pf_dhcp']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('pf_dhcp').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsPFDHCP: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('pf_dhcp').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['ports']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('ports').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsPorts: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('ports').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['provisioning']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('provisioning').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsProvisioning: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('provisioning').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['radius_configuration']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('radius_configuration').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsRadiusConfiguration: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('radius_configuration').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
  getDnsConfiguration: ({ state, commit }) => {
    if (state.cache['dns_configuration']) {
      return Promise.resolve(state.cache['dns_configuration']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('dns_configuration').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsDnsConfiguration: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('dns_configuration').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateDnsConfiguration: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'dns_configuration'
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
      return Promise.resolve(state.cache['services']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('services').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsServices: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('services').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['snmp_traps']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('snmp_traps').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsSNMPTraps: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('snmp_traps').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
      return Promise.resolve(state.cache['webservices']).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.base('webservices').then(item => {
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  optionsWebServices: ({ commit }) => {
    commit('ITEM_REQUEST')
    return api.baseOptions('webservices').then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
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
  },
  testSmtp: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.testSmtp(data).then(response => {
      commit('ITEM_SUCCESS')
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
