import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  decomposeSource,
  recomposeSource
} from '../config'
import { defaultsFromMeta } from '../../_config/'

export const useItemProps = {
  id: {
    type: String
  },
  sourceType: {
    type: String
  }
}

const useItemDefaults = (meta, props) => {
  const {
    sourceType
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), type: sourceType.value }
}

const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Authentication Source <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Authentication Source <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Authentication Source')
    }
  })
}

const useItemTitleBadge = (props, context, form) => {
  const {
    sourceType
  } = toRefs(props)
  return computed(() => (sourceType.value || form.value.type))
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'sources' }),
    goToItem: () => $router.push({ name: 'source', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneAuthenticationSource', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone,
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
    createItem: () => $store.dispatch('$_sources/createAuthenticationSource', recomposeSource(form.value)),
    deleteItem: () => $store.dispatch('$_sources/deleteAuthenticationSource', id.value),
    getItem: () => $store.dispatch('$_sources/getAuthenticationSource', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return decomposeSource(item)
    }),
    updateItem: () => $store.dispatch('$_sources/updateAuthenticationSource', recomposeSource(form.value)),
  }
}

export default {
  useItemDefaults,
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
