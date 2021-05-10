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
        return i18n.t('Floating Device <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Floating Device <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Floating Device')
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
    isLoading: computed(() => $store.getters['$_floatingdevices/isLoading']),
    getOptions: () => $store.dispatch('$_floatingdevices/options', id.value),
    createItem: () => $store.dispatch('$_floatingdevices/createFloatingDevice', form.value),
    deleteItem: () => $store.dispatch('$_floatingdevices/deleteFloatingDevice', id.value),
    getItem: () => $store.dispatch('$_floatingdevices/getFloatingDevice', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_floatingdevices/updateFloatingDevice', form.value)
  }
}
