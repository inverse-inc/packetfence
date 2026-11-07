/**
* "$_assistant" store module
*/
import Vue from 'vue'
import { v4 as uuidv4 } from 'uuid'
import api from './_api'
import basesApi from '@/views/Configuration/bases/_api'
import i18n from '@/utils/locale'

// An entry is one block of the conversation, rendered in order:
//   { type: 'user', content }
//   { type: 'bot', content, id, feedback, files, label }
//   { type: 'trace', rows }
//   { type: 'error', message }
//   { type: 'confirm', confirm, state, message, response }
//   { type: 'node_actions', node }
let entryId = 0
const entry = data => ({ key: ++entryId, ...data })

const errorMessage = err => {
  const { response: { status, data: { error, message } = {} } = {} } = err || {}
  if (error || message)
    return error || message
  switch (status) {
    case 401: return i18n.t('Not authenticated. Log in again, then retry.')
    case 403: return i18n.t('Permission denied. Your admin role lacks the required CHATBOT access.')
    case undefined: return i18n.t('Request failed. Check that the assistant service is running, then try again.')
    default: return i18n.t('Request failed (HTTP {status}).', { status })
  }
}

const state = () => ({
  threads: [],
  searchResults: null,
  threadId: null,
  entries: [],
  isSending: false,
  runId: null,
  isStopping: false,
  nodeActions: null,
  roles: null,
  settings: {},
  pfVersion: '',
  // null until the first /config answer; then whether the service answered
  isAvailable: null,
  availabilityError: '',
  // verbose trace: tool arguments, every API request, sizes and timing
  debug: localStorage.getItem('pfchatbot-debug') === '1'
})

const getters = {
  isSending: state => state.isSending,
  isStopping: state => state.isStopping,
  isNew: state => !state.entries.some(e => e.type === 'user')
}

let abortController = null

const actions = {
  init: ({ dispatch }) => {
    return Promise.all([dispatch('getConfig'), dispatch('getSettings'), dispatch('getThreads')])
  },
  getConfig: ({ commit }) => {
    return api.config().then(({ pf_version }) => {
      commit('PF_VERSION', pf_version || '')
      commit('AVAILABILITY', { isAvailable: true })
    }).catch(err => commit('AVAILABILITY', { isAvailable: false, error: errorMessage(err) }))
  },
  getSettings: ({ commit }) => {
    return api.settings().then(settings => commit('SETTINGS', settings)).catch(() => {})
  },
  getModels: () => {
    return api.models().catch(err => ({ error: errorMessage(err) }))
  },
  // the model lives in pf.conf [pfchatbot]; the assistant picks it up on its next request
  setModel: ({ dispatch }, model) => {
    return basesApi.updateBase({ id: 'pfchatbot', model, quiet: true }).then(() => dispatch('getSettings'))
  },
  getThreads: ({ commit }) => {
    return api.threads().then(threads => commit('THREADS', threads)).catch(() => {})
  },
  searchThreads: ({ commit }, q) => {
    if (!q) {
      commit('SEARCH_RESULTS', null)
      return Promise.resolve()
    }
    return api.searchThreads(q).then(items => commit('SEARCH_RESULTS', items)).catch(() => commit('SEARCH_RESULTS', []))
  },
  openThread: ({ commit, dispatch }, id) => {
    return api.thread(id).then(thread => {
      commit('THREAD_OPENED', thread)
      return dispatch('getThreads')
    }).catch(() => {})
  },
  newThread: ({ commit, dispatch }) => {
    commit('THREAD_NEW')
    return dispatch('getThreads')
  },
  deleteThread: ({ state, dispatch }, id) => {
    return api.deleteThread(id).then(() => {
      if (id === state.threadId)
        return dispatch('newThread')
      return dispatch('getThreads')
    })
  },
  send: ({ state, commit, dispatch }, { message, debug }) => {
    const text = (message || '').trim()
    if (!text || state.isSending)
      return Promise.resolve()
    const runId = uuidv4()
    const t0 = Date.now()
    abortController = new AbortController()
    commit('SEND_REQUEST', { text, runId })
    return api.chat({ message: text, thread_id: state.threadId, debug, run_id: runId }, { signal: abortController.signal }).then(response => {
      const activity = response.activity || []
      commit('SEND_SUCCESS', {
        response,
        rows: debug ? [...activity, `· round-trip ${((Date.now() - t0) / 1000).toFixed(1)}s`] : activity
      })
      if (response.node_actions)
        commit('NODE_ACTIONS', response.node_actions)
      return response
    }).catch(err => {
      commit('SEND_ERROR', (err && err.name === 'CanceledError')
        ? i18n.t('Abandoned here. Reopen the conversation to see what the server saved.')
        : errorMessage(err))
    }).finally(() => {
      abortController = null
      commit('SEND_DONE')
      dispatch('getThreads')
    })
  },
  // First press: ask the server to stop at its next tool boundary, so the
  // remaining model calls are never paid for. Second press: give up waiting.
  stop: ({ state, commit }) => {
    if (!state.isSending)
      return
    if (!state.isStopping) {
      commit('STOPPING')
      return api.cancel(state.runId).catch(() => {})
    }
    if (abortController)
      abortController.abort()
  },
  feedback: ({ commit }, { entry, rating }) => {
    const previous = entry.feedback || 0
    commit('FEEDBACK', { entry, rating })
    return api.feedback({ message_id: entry.id, rating }).catch(() => commit('FEEDBACK', { entry, rating: previous }))
  },
  confirm: ({ commit }, { entry, approved }) => {
    commit('CONFIRM', { entry, state: 'running' })
    return api.confirmWrite({ confirm_token: entry.confirm.confirm_token, approved }).then(response => {
      if (response.cancelled)
        commit('CONFIRM', { entry, state: 'cancelled', message: i18n.t('Cancelled. No change made.') })
      else if (response.executed) {
        const { result: { status_code, body } = {} } = response
        const ok = status_code && status_code < 400
        let text
        try {
          text = (typeof body === 'string') ? body : JSON.stringify(body, null, 2)
        } catch (e) {
          text = String(body)
        }
        commit('CONFIRM', {
          entry,
          state: ok ? 'done' : 'failed',
          message: (ok ? i18n.t('Done') : i18n.t('Completed')) + (status_code ? ` (HTTP ${status_code})` : ''),
          response: (text && text !== 'null' && text !== '{}') ? text : null
        })
      }
      else
        commit('CONFIRM', { entry, state: 'failed', message: response.error || i18n.t('Failed') })
    }).catch(err => {
      commit('CONFIRM', { entry, state: 'failed', message: errorMessage(err) })
    })
  },
  // node writes are staged server-side and confirmed like any chat-driven write
  stageNode: ({ commit }, { mac, action, value }) => {
    const request = {
      register: () => api.nodeStatus(mac, 'reg'),
      deregister: () => api.nodeStatus(mac, 'unreg'),
      reevaluate: () => api.nodeReevaluate(mac),
      role: () => api.nodeRole(mac, value)
    }[action]
    return request().then(response => {
      if (!response.confirm)
        throw new Error(response.error || i18n.t('Unexpected response'))
      commit('ENTRY_ADDED', entry({ type: 'confirm', confirm: response.confirm }))
      return response
    }).catch(err => {
      const message = (err && err.response) ? errorMessage(err) : (err && err.message)
      commit('ENTRY_ADDED', entry({ type: 'error', message: i18n.t('Could not prepare the change: {message}', { message }) }))
      throw err
    })
  },
  refreshNode: ({ commit }, mac) => {
    return api.node(mac).then(({ node_actions }) => {
      if (node_actions)
        commit('NODE_ACTIONS', node_actions)
    }).catch(() => {})
  },
  closeNode: ({ commit }) => commit('NODE_ACTIONS', null),
  getRoles: ({ state, commit }) => {
    if (state.roles)
      return Promise.resolve(state.roles)
    return api.roles().then(({ roles = [] }) => {
      commit('ROLES', roles)
      return roles
    }).catch(() => [])
  },
  upload: ({ state, commit, dispatch }, files) => {
    return files.reduce((promise, file) => promise.then(() => {
      const data = new FormData()
      data.append('file', file)
      data.append('thread_id', state.threadId || '')
      return api.uploadFile(data).then(response => {
        if (response.thread_id)
          commit('THREAD_ID', response.thread_id)
        commit('ENTRY_ADDED', entry({ type: 'bot', label: i18n.t('files'), content: i18n.t('Attached **{name}**. It is not indexed for search; ask me to read it and I will. Its contents go to the LLM provider when I do.', { name: response.name }) }))
      }).catch(err => {
        commit('ENTRY_ADDED', entry({ type: 'error', message: i18n.t('Could not attach {name}: {message}', { name: file.name, message: errorMessage(err) }) }))
      })
    }), Promise.resolve()).finally(() => dispatch('getThreads'))
  },
  addNote: ({ commit }, { label, content }) => {
    commit('ENTRY_ADDED', entry({ type: 'bot', label, content }))
  }
}

const mutations = {
  PF_VERSION: (state, version) => { state.pfVersion = version },
  AVAILABILITY: (state, { isAvailable, error = '' }) => {
    state.isAvailable = isAvailable
    state.availabilityError = error
  },
  SETTINGS: (state, settings) => { state.settings = settings || {} },
  THREADS: (state, threads) => { state.threads = threads || [] },
  SEARCH_RESULTS: (state, items) => { state.searchResults = items },
  THREAD_ID: (state, id) => { state.threadId = id },
  THREAD_NEW: state => {
    state.threadId = null
    state.entries = []
    state.nodeActions = null
  },
  THREAD_OPENED: (state, thread) => {
    const { id, messages = [], files = [] } = thread
    state.threadId = id
    state.nodeActions = null
    state.entries = messages.reduce((entries, m) => {
      if (m.role === 'user')
        return [...entries, entry({ type: 'user', content: m.content })]
      return [
        ...entries,
        ...((m.activity && m.activity.length) ? [entry({ type: 'trace', rows: m.activity })] : []),
        entry({ type: 'bot', content: m.content, id: m.id, feedback: m.feedback, files: files.filter(f => f.message_id === m.id) })
      ]
    }, [])
  },
  SEND_REQUEST: (state, { text, runId }) => {
    state.isSending = true
    state.isStopping = false
    state.runId = runId
    state.entries.push(entry({ type: 'user', content: text }))
  },
  SEND_SUCCESS: (state, { response, rows }) => {
    const { thread_id, reply, message_id, files, confirm, node_actions } = response
    if (thread_id)
      state.threadId = thread_id
    if (rows.length)
      state.entries.push(entry({ type: 'trace', rows }))
    state.entries.push(entry({ type: 'bot', content: reply || '', id: message_id, files }))
    if (confirm)
      state.entries.push(entry({ type: 'confirm', confirm }))
    if (node_actions)
      state.entries.push(entry({ type: 'node_actions', node: node_actions }))
  },
  SEND_ERROR: (state, message) => {
    state.entries.push(entry({ type: 'error', message }))
  },
  SEND_DONE: state => {
    state.isSending = false
    state.isStopping = false
    state.runId = null
  },
  STOPPING: state => { state.isStopping = true },
  ENTRY_ADDED: (state, item) => { state.entries.push(item) },
  FEEDBACK: (state, { entry, rating }) => { Vue.set(entry, 'feedback', rating) },
  CONFIRM: (state, { entry, ...data }) => {
    Object.keys(data).forEach(key => Vue.set(entry, key, data[key]))
  },
  NODE_ACTIONS: (state, node) => { state.nodeActions = node },
  ROLES: (state, roles) => { state.roles = roles },
  DEBUG: (state, debug) => {
    state.debug = debug
    localStorage.setItem('pfchatbot-debug', debug ? '1' : '0')
  }
}

export default { namespaced: true, state, getters, actions, mutations }
