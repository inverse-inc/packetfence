import { computed, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta
} from '../../_config/'

export const useCollectionRouter = ($router) => ({
  goToCollection: () => $router.push({ name: 'network_behavior_policies' }),
  goToItem: id => $router.push({ name: 'network_behavior_policy', params: { id } }),
  goToClone: id => $router.push({ name: 'cloneNetworkBehaviorPolicy', params: { id } }),
})

export const useCollectionStore = ($store) => ({
  isLoading: computed(() => $store.getters['$_network_behavior_policies/isLoading']),
  getOptions: () => $store.dispatch('$_network_behavior_policies/options'),
  createItem: item => $store.dispatch('$_network_behavior_policies/createNetworkBehaviorPolicy', item),
  deleteItem: id => $store.dispatch('$_network_behavior_policies/deleteNetworkBehaviorPolicy', id),
  getItem: id => $store.dispatch('$_network_behavior_policies/getNetworkBehaviorPolicy', id),
  updateItem: item => $store.dispatch('$_network_behavior_policies/updateNetworkBehaviorPolicy', item),
})

const useCollectionItemDefaults = (meta) => ({ ...defaultsFromMeta(meta), actions: [] })

export const useCollectionItemProps = {
  id: {
    type: String
  },
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
  },
}

export const useCollectionItem = (props, context, form, meta) => {

  const {
    id,
    isClone,
    isNew
  } = toRefs(props)

  const { root: { $router, $store } = {} } = context

  const {
    goToCollection,
    goToItem,
    goToClone,
  } = useCollectionRouter($router)

  const {
    isLoading,
    getOptions,
    createItem,
    deleteItem,
    getItem,
    updateItem,
  } = useCollectionStore($store)

  const title = computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Network Behavior Policy: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Network Behavior Policy: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Network Behavior Policy')
    }
  })

  const isDeletable = computed(() => {
      if (isNew.value || isClone.value)
        return false
      const { not_deletable: notDeletable = false } = form.value || {}
      if (notDeletable)
        return false
      return true
  })

  const init = () => {
    return new Promise((resolve, reject) => {
      if (!isNew.value) { // existing
        getOptions().then(options => {
          const { meta: _meta = {} } = options
          meta.value = _meta
          getItem(id.value).then(item => {
            if (isClone.value) {
              item.id = `${item.id}-${i18n.t('copy')}`
              item.not_deletable = false
            }
            form.value = item
            resolve()
          }).catch(() => {
            form.value = {}
            reject()
          })
        }).catch(() => {
          form.value = {}
          meta.value = {}
          reject()
        })
      } else { // new
        getOptions().then(options => {
          const { meta: _meta = {} } = options
          form.value = useCollectionItemDefaults(_meta)
          meta.value = _meta
          resolve()
        }).catch(() => {
          form.value = {}
          meta.value = {}
          reject()
        })
      }
    })
  }

  const create = () => createItem(form.value)

  const update = () => updateItem(form.value)

  const remove = () => deleteItem(id.value)

  const save = () => {
    if (isClone.value || isNew.value)
      return create()
    else
      return update()
  }

  watch(props, () => init(), { deep: true, immediate: true })

  return {
    form,
    meta,
    title,
    isDeletable,
    isLoading,

    reset: init,
    remove,
    save,

    goToCollection,
    goToItem,
    goToClone,
  }
}
