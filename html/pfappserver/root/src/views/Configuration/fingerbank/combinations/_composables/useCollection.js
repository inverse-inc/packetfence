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
        return i18n.t('Fingerbank Combination <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Fingerbank Combination <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Fingerbank Combination')
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
    isLoading: computed(() => $store.getters['$_fingerbank/isCombinationsLoading']),
    createItem: () => $store.dispatch('$_fingerbank/createCombination', form.value),
    deleteItem: () => $store.dispatch('$_fingerbank/deleteCombination', id.value),
    getItem: () => $store.dispatch('$_fingerbank/getCombination', id.value),
    updateItem: () => $store.dispatch('$_fingerbank/updateCombination', form.value),
  }
}
