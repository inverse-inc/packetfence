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
        return i18n.t('Realm <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Realm <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Realm')
    }
  })
}

export const useItemTitleBadge = (props, context) => {
  const {
    tenantId
  } = toRefs(props)
  const { root: { $store } = {} } = context
  const { name: tenantName } = $store.state.session.tenants.find(tenant => tenant.id === tenantId.value)
  return tenantName
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id,
    tenantId,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_realms/isLoading']),
    getOptions: () => $store.dispatch('$_realms/options', { id: id.value, tenantId: tenantId.value }),
    createItem: () => $store.dispatch('$_realms/createRealm', { item: form.value, tenantId: tenantId.value }),
    deleteItem: () => $store.dispatch('$_realms/deleteRealm', { id: id.value, tenantId: tenantId.value }),
    getItem: () => $store.dispatch('$_realms/getRealm', { id: id.value, tenantId: tenantId.value }).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_realms/updateRealm', { item: form.value, tenantId: tenantId.value }),
  }
}
