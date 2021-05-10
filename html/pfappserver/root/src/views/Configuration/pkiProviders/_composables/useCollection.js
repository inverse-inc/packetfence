import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  providerType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    providerType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: providerType.value }
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
        return i18n.t('PKI Provider <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone PKI Provider <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New PKI Provider')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    providerType
  } = toRefs(props)
  return computed(() => (providerType.value || form.value.type))
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id,
    isClone,
    isNew,
    providerType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_pki_providers/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_pki_providers/optionsByProviderType', providerType.value)
      else
        return $store.dispatch('$_pki_providers/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_pki_providers/createPkiProvider', form.value),
    deleteItem: () => $store.dispatch('$_pki_providers/deletePkiProvider', id.value),
    getItem: () => $store.dispatch('$_pki_providers/getPkiProvider', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_pki_providers/updatePkiProvider', form.value),
  }
}
