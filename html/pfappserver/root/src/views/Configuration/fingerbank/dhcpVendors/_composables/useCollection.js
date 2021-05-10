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
        return i18n.t('Fingerbank DHCP Vendor <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Fingerbank DHCP Vendor <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Fingerbank DHCP Vendor')
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
    isLoading: computed(() => $store.getters['$_fingerbank/isDhcpVendorsLoading']),
    createItem: () => $store.dispatch('$_fingerbank/createDhcpVendor', form.value),
    deleteItem: () => $store.dispatch('$_fingerbank/deleteDhcpVendor', id.value),
    getItem: () => $store.dispatch('$_fingerbank/getDhcpVendor', id.value),
    updateItem: () => $store.dispatch('$_fingerbank/updateDhcpVendor', form.value),
  }
}
