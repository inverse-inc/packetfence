import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { defaultsFromMeta } from '../../_config/'

export const useItemProps = {
  id: {
    type: String
  },
  providerType: {
    type: String
  }
}

const useItemDefaults = (meta, props) => {
  const {
    providerType
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), type: providerType.value }
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
        return i18n.t('PKI Provider: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone PKI Provider: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New PKI Provider')
    }
  })
}

const useItemTitleBadge = (props, context, form) => {
  const {
    providerType
  } = toRefs(props)
  return computed(() => (providerType.value || form.value.type))
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'pki_providers' }),
    goToItem: () => $router.push({ name: 'pki_provider', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'clonePkiProvider', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
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

export default {
  useItemDefaults,
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
