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
        return i18n.t('Fingerbank DHCPv6 Fingerprint <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Fingerbank DHCPv6 Fingerprint <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Fingerbank DHCPv6 Fingerprint')
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
    goToCollection: () => $router.push({ name: 'fingerbankDhcpv6Fingerprints' }),
    goToItem: (item = form.value || {}) => $router
      .push({ name: 'fingerbankDhcpv6Fingerprint', params: { id: item.id, scope: scope.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneFingerbankDhcpv6Fingerprint', params: { id: form.value.id || id.value, scope: 'local' } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_fingerbank/isDhcpv6FingerprintsLoading']),
    createItem: () => $store.dispatch('$_fingerbank/createDhcpv6Fingerprint', form.value),
    deleteItem: () => $store.dispatch('$_fingerbank/deleteDhcpv6Fingerprint', id.value),
    getItem: () => $store.dispatch('$_fingerbank/getDhcpv6Fingerprint', id.value),
    updateItem: () => $store.dispatch('$_fingerbank/updateDhcpv6Fingerprint', form.value),
  }
}

export default {
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
