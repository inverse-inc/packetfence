import { computed, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta as useCollectionItemDefaults
} from '../../_config/'

const useCollectionItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Domain: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Domain: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Domain')
    }
  })
}

const useCollectionRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'domains', params: { autoJoinDomain: form.value } }),
    goToItem: () => $router.push({ name: 'domain', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'cloneDomain', params: { id: id.value } }),
  }
}

const useCollectionStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_domains/isLoading']),
    getOptions: () => $store.dispatch('$_domains/options'),
    createItem: () => $store.dispatch('$_domains/createDomain', form.value),
    deleteItem: () => $store.dispatch('$_domains/deleteDomain', id.value),
    getItem: () => $store.dispatch('$_domains/getDomain', id.value),
    updateItem: () => $store.dispatch('$_domains/updateDomain', form.value),
  }
}

export default {
  useCollectionItemDefaults,
  useCollectionItemTitle,
  useCollectionRouter,
  useCollectionStore,
}
