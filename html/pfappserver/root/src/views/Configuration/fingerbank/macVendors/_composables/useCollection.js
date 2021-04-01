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
        return i18n.t('Fingerbank MAC Vendor <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Fingerbank MAC Vendor <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Fingerbank MAC Vendor')
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
    goToCollection: () => $router.push({ name: 'fingerbankMacVendors' }),
    goToItem: (item = form.value || {}) => $router
      .push({ name: 'fingerbankMacVendor', params: { id: item.id, scope: scope.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneFingerbankMacVendor', params: { id: form.value.id || id.value, scope: 'local' } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_fingerbank/isMacVendorsLoading']),
    createItem: () => $store.dispatch('$_fingerbank/createMacVendor', form.value),
    deleteItem: () => $store.dispatch('$_fingerbank/deleteMacVendor', id.value),
    getItem: () => $store.dispatch('$_fingerbank/getMacVendor', id.value),
    updateItem: () => $store.dispatch('$_fingerbank/updateMacVendor', form.value),
  }
}

export default {
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
