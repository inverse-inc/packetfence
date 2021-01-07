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
        return i18n.t('Fingerbank DHCPv6 Enterprise: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Fingerbank DHCPv6 Enterprise: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Fingerbank DHCPv6 Enterprise')
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
    goToCollection: () => $router.push({ name: 'fingerbankDhcpv6Enterprises' }),
    goToItem: () => $router.push({ name: 'fingerbankDhcpv6Enterprise', params: { id: form.value.id || id.value, scope: scope.value } }),
    goToClone: () => $router.push({ name: 'cloneFingerbankDhcpv6Enterprise', params: { id: form.value.id || id.value, scope: 'local' } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_fingerbank/isDhcpv6EnterprisesLoading']),
    createItem: () => $store.dispatch('$_fingerbank/createDhcpv6Enterprise', form.value),
    deleteItem: () => $store.dispatch('$_fingerbank/deleteDhcpv6Enterprise', id.value),
    getItem: () => $store.dispatch('$_fingerbank/getDhcpv6Enterprise', id.value),
    updateItem: () => $store.dispatch('$_fingerbank/updateDhcpv6Enterprise', form.value),
  }
}

export default {
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
