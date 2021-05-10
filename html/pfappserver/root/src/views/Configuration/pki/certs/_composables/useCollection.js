import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  profile_id: {
    type: String
  }
}

export const useItemDefaults = (meta, props) => {
  const {
    profile_id
  } = toRefs(props)
  return { profile_id: profile_id.value }
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
        return i18n.t('Certificate <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Certificate <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Certificate')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id,
    profile_id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_pkis/isLoading']),
    createItem: () => $store.dispatch('$_pkis/createCert', { ...form.value, profile_id: profile_id.value }),
    getItem: () => $store.dispatch('$_pkis/getCert', id.value)
  }
}
