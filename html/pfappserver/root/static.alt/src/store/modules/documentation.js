/**
* "documentation" store module
*/
import Vue from 'vue'
import store from '@/store'
import { documentationCall } from '@/utils/api'

const api = {
  getDocuments: () => {
    return documentationCall.get('index.js').then(response => {
      return response.data.items
    })
  }
}

const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

const state = {
  documents: false,
  fullscreen: false,
  showViewer: true,
  message: '',
  requestStatus: ''
}

const getters = {
  isLoading: state => state.requestStatus === types.LOADING,
  documents: state => state.documents
}

const actions = {
  getDocuments: ({ commit, state }) => {
    if (state.documents) {
      return Promise.resolve(state.documents)
    }
    commit('DOCUMENTS_REQUEST')
    return new Promise((resolve, reject) => {
      api.getDocuments().then(data => {
        commit('DOCUMENTS_SUCCESS', data)
        resolve(state.documents)
      }).catch(err => {
        commit('DOCUMENTS_ERROR', err.response)
        reject(err)
      })
    })
  },
  openViewer: ({ commit, state }) => {
    if (!state.showViewer) {
      commit('VIEWER_OPEN')
    }
  },
  closeViewer: ({ commit, state }) => {
    if (state.showViewer) {
      commit('VIEWER_CLOSE')
    }
  },
  toggleFullscreen: ({ commit, state }) => {
    if (state.fullscreen) {
      commit('FULLSCREEN_OFF')
    } else {
      commit('FULLSCREEN_ON')
    }
  }
}

const mutations = {
  DOCUMENTS_REQUEST: (state) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  DOCUMENTS_SUCCESS: (state, data) => {
    Vue.set(state, 'documents', data)
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  DOCUMENTS_ERROR: (state, data) => {
    state.requestStatus = types.ERROR
    const { response: { data: { message } = {} } = {} } = data
    if (message) {
      state.message = message
    }
  },
  VIEWER_OPEN: (state) => {
    state.showViewer = true
  },
  VIEWER_CLOSE: (state) => {
    state.showViewer = false
  },
  FULLSCREEN_OFF: (state) => {
    state.fullscreen = false
  },
  FULLSCREEN_ON: (state) => {
    state.fullscreen = true
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
