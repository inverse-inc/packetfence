/**
* "$_live_logs" store module
*/
import store from '@/store'
import { v4 as uuidv4 } from 'uuid'
import api from '../_api'
import SessionStore from './session'
import i18n from '@/utils/locale'

// Cluster fan-out — when isCluster (Object.keys(servers).length > 1) and
// not SaaS, createSession opens one tail session per peer using the
// X-PacketFence-Server header to pin each request. We then register one
// submodule per peer under a synthetic group_id. The group_id is what the
// router uses for the :id URL; the View component concatenates events
// across the peer submodules looked up via _groups[group_id].
//
// Standalone / single-node paths keep the legacy shape exactly: one
// session, one submodule, _groups[session_id] = [session_id].
const peerList = () => {
  const servers = store.state.cluster && store.state.cluster.servers
  if (!servers) return []
  return Object.values(servers).filter(s => s && s.management_ip)
}

// Default values
const state = () => {
  return {
    _lastSessionId: null,
    _groups: {},
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
  },
  groupPeers: state => groupId => state._groups[groupId] || [groupId]
}

// Extracted from createSession so the cluster-config preload above can chain
// into it cleanly with a single return path (cluster fan-out vs legacy single).
const startSessions = (commit, form, saas, isCluster) => {
  if (isCluster) {
    const servers = peerList()
    const group_id = uuidv4()
    return Promise.all(servers.map(server =>
      api.create(form, server).then(response => ({ server, response }))
                              .catch(err => ({ server, error: err }))
    )).then(results => {
      const peers = results
        .filter(r => r.response && r.response.session_id)
        .map(r => ({
          hostname: r.server.host,
          management_ip: r.server.management_ip,
          session_id: r.response.session_id
        }))
      if (peers.length === 0) {
        commit('LOG_SESSION_ERROR', { data: { message: 'No cluster node could start a session' } })
        return { error: true }
      }
      commit('LOG_GROUP_START', { group_id, peers })
      peers.forEach(peer => {
        commit('LOG_SESSION_START', {
          form,
          response: { session_id: peer.session_id },
          peer
        })
      })
      return { session_id: group_id, group_id, peers }
    })
  }

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
    // Ensure cluster config is loaded before deciding fan-out. Without this
    // a user who clicks Start immediately after the page loads races with
    // cluster/getConfig and silently falls back to the local-only single-
    // session path — and then Stop on a "phantom" peer session 404s. Re-
    // dispatching getConfig is cheap and the backend response is small.
    const needsClusterLoad = !saas && (
      !store.state.cluster ||
      !store.state.cluster.servers ||
      Object.keys(store.state.cluster.servers).length === 0
    )
    const clusterReady = needsClusterLoad
      ? store.dispatch('cluster/getConfig').catch(() => null)
      : Promise.resolve()

    return clusterReady.then(() => {
      const isCluster = !saas && store.getters['cluster/isCluster']
      return startSessions(commit, form, saas, isCluster)
    })
  },
  destroySession: ({ state, commit }, id) => {
    // _groups[id] is an array of full peer objects {hostname, management_ip, session_id}
    // so we don't depend on each per-peer submodule still having state.session.peer
    // populated (which can race when the user clicks Stop right after creation).
    const group = state._groups[id]
    const peers = group || [{ session_id: id, management_ip: null }]
    const stopOne = peer => {
      const sid = peer.session_id
      if (!store.getters[`$_live_logs/${sid}/isRunning`]) {
        commit('LOG_SESSION_STOP', sid)
        return Promise.resolve()
      }
      // Pass the peer explicitly so the X-PacketFence-Server header is set
      // regardless of submodule state.
      return store.dispatch(`$_live_logs/${sid}/stopSession`, peer)
        .then(() => commit('LOG_SESSION_STOP', sid))
        .catch(err => {
          commit('LOG_SESSION_STOP', sid)
          commit('LOG_SESSION_ERROR', err && err.response)
        })
    }
    commit('LOG_SESSION_REQUEST')
    return Promise.all(peers.map(stopOne)).finally(() => {
      if (group) commit('LOG_GROUP_STOP', id)
    })
  }
}

const mutations = {
  LOG_SESSION_REQUEST: (state) => {
    state.status = 'loading'
    state.message = ''
  },
  LOG_SESSION_START: (state, { form, response, cursor, peer }) => {
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
      store.dispatch(`$_live_logs/${session_id}/setSession`, {
        ...form,
        session_id,
        name: nameFromFiles(form.files),
        ...(cursor != null ? { cursor } : {}),
        ...(peer ? { peer } : {})
      })
    }
  },
  LOG_GROUP_START: (state, { group_id, peers }) => {
    // Store full peer objects ({hostname, management_ip, session_id}) so the
    // destroy/stop path can build the X-PacketFence-Server header without
    // hopping through each per-peer submodule's state.
    state._groups = { ...state._groups, [group_id]: peers.slice() }
  },
  LOG_GROUP_STOP: (state, group_id) => {
    if (state._lastSessionId === group_id) state._lastSessionId = null
    const next = { ...state._groups }
    delete next[group_id]
    state._groups = next
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
