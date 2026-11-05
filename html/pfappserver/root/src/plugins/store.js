/**
 * The store of a plugin page: a "$_plugin_<id>" module registered when a page
 * of the plugin is entered (unregistered on logout like the other "$_" modules),
 * the same as the _store.js of the core views, built from the manifest api.
 */
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import { types } from '@/store'
import i18n from '@/utils/locale'
import { makeApi } from './api'

export const storeName = id => `$_plugin_${id.replace(/-/g, '_')}`

const makeModule = api => {
  const state = () => ({
    cache: {}, // items details
    message: '',
    itemStatus: ''
  })

  const getters = {
    isWaiting: state => [types.LOADING, types.DELETING].includes(state.itemStatus),
    isLoading: state => state.itemStatus === types.LOADING
  }

  const request = (commit, call, status) => {
    commit('ITEM_REQUEST', status)
    return call().then(response => {
      commit('ITEM_SUCCESS')
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  }

  const actions = {
    listOptions: ({ commit }) => request(commit, () => api.listOptions()),
    itemOptions: ({ commit }, id) => request(commit, () => api.itemOptions(id)),
    getItem: ({ state, commit }, id) => {
      const key = id || ''
      if (state.cache[key])
        return Promise.resolve(JSON.parse(JSON.stringify(state.cache[key])))
      return request(commit, () => api.item(id)).then(item => {
        commit('ITEM_REPLACED', { key, item })
        return JSON.parse(JSON.stringify(item))
      })
    },
    createItem: ({ commit }, data) => request(commit, () => api.create(data)).then(response => {
      commit('ITEM_REPLACED', { key: data.id, item: data })
      return response
    }),
    updateItem: ({ commit }, data) => request(commit, () => api.update(data)).then(response => {
      commit('ITEM_REPLACED', { key: data.id || '', item: data })
      return response
    }),
    deleteItem: ({ commit }, id) => request(commit, () => api.delete(id), types.DELETING).then(response => {
      commit('ITEM_DESTROYED', id)
      return response
    })
  }

  const mutations = {
    ITEM_REQUEST: (state, type) => {
      state.itemStatus = type || types.LOADING
      state.message = ''
    },
    ITEM_REPLACED: (state, { key, item }) => {
      state.itemStatus = types.SUCCESS
      Vue.set(state.cache, key, JSON.parse(JSON.stringify(item)))
    },
    ITEM_DESTROYED: (state, id) => {
      state.itemStatus = types.SUCCESS
      Vue.set(state.cache, id, null)
    },
    ITEM_ERROR: (state, response) => {
      state.itemStatus = types.ERROR
      if (response && response.data)
        state.message = response.data.message
    },
    ITEM_SUCCESS: state => {
      state.itemStatus = types.SUCCESS
    }
  }

  return { namespaced: true, state, getters, actions, mutations }
}

const apis = new WeakMap()
export const pluginApi = manifest => {
  if (!apis.has(manifest))
    apis.set(manifest, makeApi(manifest))
  return apis.get(manifest)
}

// register the store module of a plugin, in a route beforeEnter
export const registerStore = ($store, { id, manifest }) => {
  const name = storeName(id)
  if (!$store.state[name])
    $store.registerModule(name, makeModule(pluginApi(manifest)))
}

/**
 * useStore for useViewCollectionItem / useViewResource and the search: a
 * method is only defined when the manifest api has it, the views hide what is
 * missing (Save, Clone, Delete, ...).
 */
export const useStore = ({ id, manifest }) => $store => {
  const name = storeName(id)
  const { api = {} } = manifest
  const dispatch = (action, ...args) => {
    registerStore($store, { id, manifest })
    return $store.dispatch(`${name}/${action}`, ...args)
  }
  const isCollection = manifest.template === 'collection'
  return {
    isLoading: computed(() => !!$store.getters[`${name}/isLoading`]),
    ...((api.listOptions) ? { getListOptions: () => dispatch('listOptions') } : {}),
    ...((api.create) ? { createItem: params => dispatch('createItem', params) } : {}),
    getItem: params => dispatch('getItem', (isCollection) ? params.id : undefined).then(item => {
      return (isCollection && params.isClone)
        ? { ...item, id: `${item.id}-${i18n.t('copy')}`, not_deletable: false }
        : item
    }),
    ...((api.itemOptions) ? { getItemOptions: params => dispatch('itemOptions', (isCollection) ? params.id : undefined) } : {}),
    ...((api.update) ? { updateItem: params => dispatch('updateItem', params) } : {}),
    ...((api.delete) ? { deleteItem: params => dispatch('deleteItem', params.id) } : {})
  }
}
