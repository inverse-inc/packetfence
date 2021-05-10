import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  moduleType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    moduleType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: moduleType.value }
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
        return i18n.t('Portal Module <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Portal Module <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Portal Module')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    moduleType
  } = toRefs(props)
  return computed(() => (moduleType.value || form.value.type))
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id,
    isClone,
    isNew,
    moduleType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_portalmodules/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_portalmodules/optionsByModuleType', moduleType.value)
      else
        return $store.dispatch('$_portalmodules/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_portalmodules/createPortalModule', form.value),
    deleteItem: () => $store.dispatch('$_portalmodules/deletePortalModule', id.value),
    getItem: () => $store.dispatch('$_portalmodules/getPortalModule', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_portalmodules/updatePortalModule', form.value),
  }
}
