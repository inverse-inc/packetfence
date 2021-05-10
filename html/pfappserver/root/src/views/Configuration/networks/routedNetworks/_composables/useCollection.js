import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Routed Network <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Routed Network <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Routed Network')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_routed_networks/isLoading']),
    getOptions: () => $store.dispatch('$_routed_networks/options'),
    createItem: () => $store.dispatch('$_routed_networks/createRoutedNetwork', form.value),
    deleteItem: () => $store.dispatch('$_routed_networks/deleteRoutedNetwork', id.value),
    getItem: () => $store.dispatch('$_routed_networks/getRoutedNetwork', id.value),
    updateItem: () => $store.dispatch('$_routed_networks/updateRoutedNetwork', form.value),
  }
}
