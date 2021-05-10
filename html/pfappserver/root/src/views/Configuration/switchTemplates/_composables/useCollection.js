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
        return i18n.t('Switch Template <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Switch Template <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Switch Template')
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
    isLoading: computed(() => $store.getters['$_switch_templates/isLoading']),
    getOptions: () => $store.dispatch('$_switch_templates/options'),
    createItem: () => $store.dispatch('$_switch_templates/createSwitchTemplate', form.value),
    deleteItem: () => $store.dispatch('$_switch_templates/deleteSwitchTemplate', id.value),
    getItem: () => $store.dispatch('$_switch_templates/getSwitchTemplate', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}_${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_switch_templates/updateSwitchTemplate', form.value),
  }
}
