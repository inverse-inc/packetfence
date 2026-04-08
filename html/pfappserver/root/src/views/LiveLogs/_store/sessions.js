/**
* "$_live_logs" store module
*/
import store from '@/store'
import { v4 as uuidv4 } from 'uuid'
import api from '../_api'
import SessionStore from './session'
import i18n from '@/utils/locale'

// Default values
const state = () => {
  return {
    _lastSessionId: null,
    message: '',
    status: ''
  }
}

const getters = {
  isLoading: state => state.status === 'loading',
  sessions: state => {
    return (Object.keys(state) || []).filter(key => {
      let [ , namespace ] = /^([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$/.exec(key) || []
      return namespace
    }).map(namespace => {
      return store.getters[`$_live_logs/${namespace}/session`]
    })
  }
}

const actions = {
  optionsSession: ({ commit }) => {
    commit('LOG_SESSION_REQUEST')
    return api.options().then(response => {
      commit('LOG_SESSION_SUCCESS')
      return response
    }).catch(err => {
      commit('LOG_SESSION_ERROR', err.response)
      return err
    })
  },
  createSession: ({ commit }, form) => {
    commit('LOG_SESSION_REQUEST')
    const saas = store.getters['system/isSaas']
    return api.create(form).then(response => {
      let session_id
      if (saas) {
        session_id = uuidv4()
        commit('LOG_SESSION_START', { form, response: { session_id }, cursor: response.cursor })
      } else {
        session_id = response.session_id
        commit('LOG_SESSION_START', { form, response })
      }
      return { ...response, session_id }
    }).catch(err => {
      commit('LOG_SESSION_ERROR', err.response)
      return err
    })
  },
  destroySession: ({ commit }, id) => {
    if (!store.getters[`$_live_logs/${id}/isRunning`]) {
      commit('LOG_SESSION_STOP', id)
    }
    else {
      commit('LOG_SESSION_REQUEST')
      return api.delete(id).then(response => {
        commit('LOG_SESSION_STOP', id)
        return response
      }).catch(err => {
        commit('LOG_SESSION_STOP', id)
        commit('LOG_SESSION_ERROR', err.response)
        return err
      })
    }
  }
}

const mutations = {
  LOG_SESSION_REQUEST: (state) => {
    state.status = 'loading'
    state.message = ''
  },
  LOG_SESSION_START: (state, { form, response, cursor }) => {
    state.status = 'success'
    const { session_id } = response
    if (session_id) {
      const nameFromFiles = (files) => {
        let name = files[0].split('/').reverse()[0]
        if (files.length > 1) {
          name += `...(+${files.length - 1} ${i18n.t('more')})` // '...(+n more)'
        }
        return name
      }
      store.registerModule(['$_live_logs', session_id], SessionStore)
      store.dispatch(`$_live_logs/${session_id}/setSession`, { ...form, session_id, name: nameFromFiles(form.files), ...(cursor != null ? { cursor } : {}) })
    }
  },
  SET_LAST_SESSION: (state, id) => {
    state._lastSessionId = id
  },
  LOG_SESSION_STOP: (state, id) => {
    state.status = 'success'
    if (state._lastSessionId === id) {
      state._lastSessionId = null
    }
    setTimeout(() => { // delay to avoid pulling the rug out from under $router
      store.unregisterModule(['$_live_logs', id])
    }, 300)
  },
  LOG_SESSION_SUCCESS: (state) => {
    state.status = 'success'
  },
  LOG_SESSION_ERROR: (state, response) => {
    state.status = 'error'
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
