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

const useItemTitle = (props) => {
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

const useRouter = (props, context, form) => {
  const {
    id,
    scope
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'fingerbankCombinations' }),
    goToItem: () => $router.push({ name: 'fingerbankCombination', params: { id: form.value.id || id.value, scope: scope.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneFingerbankCombination', params: { id: form.value.id || id.value, scope: 'local' } }),
  }
}

const useStore = (props, context, form) => {
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

export default {
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
