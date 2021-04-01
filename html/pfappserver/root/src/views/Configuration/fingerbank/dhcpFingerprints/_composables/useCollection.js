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
        return i18n.t('Fingerbank DHCP Fingerprint <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Fingerbank DHCP Fingerprint <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Fingerbank DHCP Fingerprint')
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
    goToCollection: () => $router.push({ name: 'fingerbankDhcpFingerprints' }),
    goToItem: (item = form.value || {}) => $router
      .push({ name: 'fingerbankDhcpFingerprint', params: { id: item.id, scope: scope.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneFingerbankDhcpFingerprint', params: { id: form.value.id || id.value, scope: 'local' } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_fingerbank/isDhcpFingerprintsLoading']),
    createItem: () => $store.dispatch('$_fingerbank/createDhcpFingerprint', form.value),
    deleteItem: () => $store.dispatch('$_fingerbank/deleteDhcpFingerprint', id.value),
    getItem: () => $store.dispatch('$_fingerbank/getDhcpFingerprint', id.value),
    updateItem: () => $store.dispatch('$_fingerbank/updateDhcpFingerprint', form.value),
  }
}

export default {
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
