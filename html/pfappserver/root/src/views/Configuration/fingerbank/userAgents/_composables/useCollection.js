import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  scope: {
    type: String
  }
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
        return i18n.t('Fingerbank User Agent <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Fingerbank User Agent <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Fingerbank User Agent')
    }
  })
}

export const useItemTitleBadge = props => props.scope

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_fingerbank/isUserAgentsLoading']),
    createItem: () => $store.dispatch('$_fingerbank/createUserAgent', form.value),
    deleteItem: () => $store.dispatch('$_fingerbank/deleteUserAgent', id.value),
    getItem: () => $store.dispatch('$_fingerbank/getUserAgent', id.value),
    updateItem: () => $store.dispatch('$_fingerbank/updateUserAgent', form.value),
  }
}
