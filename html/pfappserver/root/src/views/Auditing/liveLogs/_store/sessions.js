/**
* "$_live_logs" store module
*/
import store from '@/store'
import api from '../_api'
import SessionStore from './session'
import i18n from '@/utils/locale'

// Default values
const state = () => {
  return {
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
    return api.create(form).then(response => {
      commit('LOG_SESSION_START', { form, response })
      return response
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
  LOG_SESSION_START: (state, { form, response }) => {
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
      store.dispatch(`$_live_logs/${session_id}/setSession`, { ...form, session_id, name: nameFromFiles(form.files) })
    }
  },
  LOG_SESSION_STOP: (state, id) => {
    state.status = 'success'
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
