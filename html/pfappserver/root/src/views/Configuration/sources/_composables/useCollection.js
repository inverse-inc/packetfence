import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  sourceType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    sourceType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: sourceType.value }
}

export const useItemTitle = (props) => {
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

export const useItemTitleBadge = (props, context, form) => {
  const {
    sourceType
  } = toRefs(props)
  return computed(() => (sourceType.value || form.value.type))
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
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
    createItem: () => $store.dispatch('$_sources/createAuthenticationSource', form.value),
    deleteItem: () => $store.dispatch('$_sources/deleteAuthenticationSource', id.value),
    getItem: () => $store.dispatch('$_sources/getAuthenticationSource', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_sources/updateAuthenticationSource', form.value),
  }
}
