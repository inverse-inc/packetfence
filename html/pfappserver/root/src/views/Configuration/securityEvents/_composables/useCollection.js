import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Security Event <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Security Event <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Security Event')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_security_events/isLoading']),
    getOptions: () => $store.dispatch('$_security_events/options'),
    createItem: () => $store.dispatch('$_security_events/createSecurityEvent', form.value),
    deleteItem: () => $store.dispatch('$_security_events/deleteSecurityEvent', id.value),
    getItem: () => $store.dispatch('$_security_events/getSecurityEvent', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_security_events/updateSecurityEvent', form.value),
  }
}
