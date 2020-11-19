import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta
} from '../../_config/'

const useCollectionItemDefaults = (meta) => ({ ...defaultsFromMeta(meta), actions: [] })

const useCollectionItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Network Behavior Policy: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Network Behavior Policy: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Network Behavior Policy')
    }
  })
}

const useCollectionRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'network_behavior_policies' }),
    goToItem: () => $router.push({ name: 'network_behavior_policy', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'cloneNetworkBehaviorPolicy', params: { id: id.value } }),
  }
}

const useCollectionStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_network_behavior_policies/isLoading']),
    getOptions: () => $store.dispatch('$_network_behavior_policies/options'),
    createItem: () => $store.dispatch('$_network_behavior_policies/createNetworkBehaviorPolicy', form.value),
    deleteItem: () => $store.dispatch('$_network_behavior_policies/deleteNetworkBehaviorPolicy', id.value),
    getItem: () => $store.dispatch('$_network_behavior_policies/getNetworkBehaviorPolicy', id.value),
    updateItem: () => $store.dispatch('$_network_behavior_policies/updateNetworkBehaviorPolicy', form.value),
  }
}

export default {
  useCollectionItemDefaults,
  useCollectionItemTitle,
  useCollectionRouter,
  useCollectionStore,
}
