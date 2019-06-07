/**
* "documentation" store module
*/
import Vue from 'vue'
import { documentationCall } from '@/utils/api'

const api = {
  getDocuments: () => {
    return documentationCall.get('index.js').then(response => {
      return response.data.items
    })
  },
  getDocument: (filename) => {
    return documentationCall.get(filename).then(response => {
      return response.data
    })
  }
}

const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

const state = {
  cache: {},
  index: false,
  fullscreen: false,
  showViewer: false,
  message: '',
  requestStatus: ''
}

const getters = {
  isLoading: state => state.requestStatus === types.LOADING,
  index: state => state.index,
  showViewer: state => state.showViewer
}

const actions = {
  getIndex: ({ commit, state }) => {
    if (state.index) {
      return Promise.resolve(state.index)
    }
    commit('INDEX_REQUEST')
    return new Promise((resolve, reject) => {
      api.getDocuments().then(data => {
        commit('INDEX_SUCCESS', data)
        resolve(state.index)
      }).catch(err => {
        commit('INDEX_ERROR', err.response)
        reject(err)
      })
    })
  },
  getDocument: ({ commit, state }, filename) => {
    if (state.cache && filename in state.cache) {
      return Promise.resolve(state.cache[filename])
    }
    commit('DOCUMENT_REQUEST')
    return new Promise((resolve, reject) => {
      api.getDocument(filename).then(response => {
        commit('DOCUMENT_SUCCESS', { filename, response })
        resolve(state.cache[filename])
      }).catch(err => {
        commit('DOCUMENT_ERROR', err.response)
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
  toggleViewer: ({ commit, state }) => {
    if (!state.showViewer) {
      commit('VIEWER_OPEN')
    } else {
      commit('FULLSCREEN_OFF')
      commit('VIEWER_CLOSE')
    }
  },
  toggleFullscreen: ({ commit, state }) => {
    if (!state.fullscreen) {
      commit('FULLSCREEN_ON')
    } else {
      commit('FULLSCREEN_OFF')
    }
  }
}

const mutations = {
  INDEX_REQUEST: (state) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  INDEX_SUCCESS: (state, data) => {
    Vue.set(state, 'index', data)
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  INDEX_ERROR: (state, data) => {
    state.requestStatus = types.ERROR
    const { response: { data: { message } = {} } = {} } = data
    if (message) {
      state.message = message
    }
  },
  DOCUMENT_REQUEST: (state) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  DOCUMENT_SUCCESS: (state, data) => {
    Vue.set(state.cache, data.filename, data.response)
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  DOCUMENT_ERROR: (state, data) => {
    state.requestStatus = types.ERROR
    if (data) {
      const { response: { data: { message } = {} } = {} } = data
      if (message) {
        state.message = message
      }
    }
  },
  VIEWER_OPEN: (state) => {
    Vue.set(state, 'showViewer', true)
  },
  VIEWER_CLOSE: (state) => {
    Vue.set(state, 'showViewer', false)
  },
  FULLSCREEN_ON: (state) => {
    Vue.set(state, 'fullscreen', true)
  },
  FULLSCREEN_OFF: (state) => {
    Vue.set(state, 'fullscreen', false)
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
