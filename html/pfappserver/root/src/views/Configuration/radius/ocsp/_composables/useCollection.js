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
        return i18n.t('OCSP Profile <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone OCSP Profile <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New OCSP Profile')
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
    isLoading: computed(() => $store.getters['$_radius_ocsp/isLoading']),
    getOptions: () => $store.dispatch('$_radius_ocsp/options'),
    createItem: () => $store.dispatch('$_radius_ocsp/createRadiusOcsp', form.value),
    deleteItem: () => $store.dispatch('$_radius_ocsp/deleteRadiusOcsp', id.value),
    getItem: () => $store.dispatch('$_radius_ocsp/getRadiusOcsp', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    ...((id.value === 'default' && !isClone.value)
      ? {} // don't update id: default
      : {
        updateItem: () => $store.dispatch('$_radius_ocsp/updateRadiusOcsp', form.value)
      }
    )
  }
}
