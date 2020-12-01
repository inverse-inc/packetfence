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
        return i18n.t('Fingerbank DHCP Vendor: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Fingerbank DHCP Vendor: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Fingerbank DHCP Vendor')
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
    goToCollection: () => $router.push({ name: 'fingerbankDhcpVendors' }),
    goToItem: () => $router.push({ name: 'fingerbankDhcpVendor', params: { id: form.value.id || id.value, scope: scope.value } }),
    goToClone: () => $router.push({ name: 'cloneFingerbankDhcpVendor', params: { id: form.value.id || id.value, scope: 'local' } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_fingerbank/isDhcpVendorsLoading']),
    createItem: () => $store.dispatch('$_fingerbank/createDhcpVendor', form.value),
    deleteItem: () => $store.dispatch('$_fingerbank/deleteDhcpVendor', id.value),
    getItem: () => $store.dispatch('$_fingerbank/getDhcpVendor', id.value),
    updateItem: () => $store.dispatch('$_fingerbank/updateDhcpVendor', form.value),
  }
}

export default {
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
