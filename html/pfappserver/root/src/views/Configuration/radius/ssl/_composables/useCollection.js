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
        return i18n.t('SSL Certificate <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone SSL Certificate <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New SSL Certificate')
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
    isLoading: computed(() => $store.getters['$_radius_ssl/isLoading']),
    getOptions: () => $store.dispatch('$_radius_ssl/options'),
    createItem: () => $store.dispatch('$_radius_ssl/createRadiusSsl', form.value),
    deleteItem: () => $store.dispatch('$_radius_ssl/deleteRadiusSsl', id.value),
    getItem: () => $store.dispatch('$_radius_ssl/getRadiusSsl', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_radius_ssl/updateRadiusSsl', form.value),
  }
}
