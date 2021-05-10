import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta) => ({ ...useDefaultsFromMeta(meta), actions: [] })

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Network Behavior Policy <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Network Behavior Policy <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Network Behavior Policy')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_network_behavior_policies/isLoading']),
    getOptions: () => $store.dispatch('$_network_behavior_policies/options'),
    createItem: () => $store.dispatch('$_network_behavior_policies/createNetworkBehaviorPolicy', form.value),
    deleteItem: () => $store.dispatch('$_network_behavior_policies/deleteNetworkBehaviorPolicy', id.value),
    getItem: () => $store.dispatch('$_network_behavior_policies/getNetworkBehaviorPolicy', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_network_behavior_policies/updateNetworkBehaviorPolicy', form.value),
  }
}
