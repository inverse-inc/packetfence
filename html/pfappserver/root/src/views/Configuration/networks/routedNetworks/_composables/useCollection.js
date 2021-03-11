import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta as useItemDefaults
} from '../../../_config/'

const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Routed Network: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Routed Network: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Routed Network')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'interfaces' }),
    goToItem: () => $router.push({ name: 'routed_network', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneRoutedNetwork', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
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

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
