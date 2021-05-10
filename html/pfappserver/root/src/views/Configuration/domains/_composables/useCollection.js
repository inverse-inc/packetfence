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
        return i18n.t('Domain <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Domain <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Domain')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_domains/isLoading']),
    getOptions: () => $store.dispatch('$_domains/options'),
    createItem: () => $store.dispatch('$_domains/createDomain', form.value),
    deleteItem: () => $store.dispatch('$_domains/deleteDomain', id.value),
    getItem: () => $store.dispatch('$_domains/getDomain', id.value),
    updateItem: () => $store.dispatch('$_domains/updateDomain', form.value),
  }
}
