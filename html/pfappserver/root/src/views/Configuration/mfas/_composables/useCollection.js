import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { defaultsFromMeta } from '../../_config/'

export const useItemProps = {
  id: {
    type: String
  },
  mfaType: {
    type: String
  }
}

const useItemDefaults = (meta, props) => {
  const {
    mfaType
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), type: mfaType.value }
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
        return i18n.t('MFA Service <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone MFA Service <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New MFA Service')
    }
  })
}

const useItemTitleBadge = (props, context, form) => {
  const {
    mfaType
  } = toRefs(props)
  return computed(() => (mfaType.value || form.value.type))
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'mfas' }),
    goToItem: (item = form.value || {}) => $router
      .push({ name: 'mfa', params: { id: item.id } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'mfaCloud', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone,
    isNew,
    mfaType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_mfas/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_mfas/optionsByMfaType', mfaType.value)
      else
        return $store.dispatch('$_mfas/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_mfas/createMfa', form.value),
    deleteItem: () => $store.dispatch('$_mfas/deleteMfa', id.value),
    getItem: () => $store.dispatch('$_mfas/getMfa', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_mfas/updateMfa', form.value),
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
