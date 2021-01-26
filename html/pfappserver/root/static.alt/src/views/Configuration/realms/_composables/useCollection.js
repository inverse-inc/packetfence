import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta as useItemDefaults
} from '../../_config/'

const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Realm: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Realm: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Realm')
    }
  })
}

const useItemTitleBadge = (props, context) => {
  const {
    tenantId
  } = toRefs(props)
  const { root: { $store } = {} } = context
  const { name: tenantName } = $store.state.session.tenants.find(tenant => tenant.id === tenantId.value)
  return tenantName
}

const useRouter = (props, context, form) => {
  const {
    id,
    tenantId
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'realms', params: { tenantId: tenantId.value } }),
    goToItem: () => $router.push({ name: 'realm', params: { id: form.value.id || id.value, tenantId: tenantId.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneRealm', params: { id: id.value, tenantId: tenantId.value } }),
  }
}

const useStore = (props, context, form) => {
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

export default {
  useItemDefaults,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
