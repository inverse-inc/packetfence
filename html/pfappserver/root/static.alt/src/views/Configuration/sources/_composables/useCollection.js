import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { defaultsFromMeta } from '../../_config/'

export const useCollectionItemProps = {
  id: {
    type: String
  },
  sourceType: {
    type: String
  }
}

const useCollectionItemDefaults = (meta, props) => {
  const {
    sourceType
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), type: sourceType.value }
}

const useCollectionItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Authentication Source: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Authentication Source: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Authentication Source')
    }
  })
}

const useCollectionRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'sources' }),
    goToItem: () => $router.push({ name: 'source', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'cloneAuthenticationSource', params: { id: id.value } }),
  }
}

const useCollectionStore = (props, context, form) => {
  const {
    id,
    isNew,
    sourceType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_sources/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_sources/optionsBySourceType', sourceType.value)
      else
        return $store.dispatch('$_sources/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_sources/createAuthenticationSource', form.value),
    deleteItem: () => $store.dispatch('$_sources/deleteAuthenticationSource', id.value),
    getItem: () => $store.dispatch('$_sources/getAuthenticationSource', id.value),
    updateItem: () => $store.dispatch('$_sources/updateAuthenticationSource', form.value),
  }
}

export default {
  useCollectionItemDefaults,
  useCollectionItemProps,
  useCollectionItemTitle,
  useCollectionRouter,
  useCollectionStore,
}
