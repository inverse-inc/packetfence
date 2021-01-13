import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { defaultsFromMeta } from '../../_config/'

export const useItemProps = {
  id: {
    type: String
  },
  firewallType: {
    type: String
  }
}

const useItemDefaults = (meta, props) => {
  const {
    firewallType
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), type: firewallType.value }
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
        return i18n.t('Firewall SSO: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Firewall SSO: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Firewall SSO')
    }
  })
}

const useItemTitleBadge = (props, context, form) => {
  const {
    firewallType
  } = toRefs(props)
  return computed(() => (firewallType.value || form.value.type))
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'firewalls' }),
    goToItem: () => $router.push({ name: 'firewall', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneFirewall', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone,
    isNew,
    firewallType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_firewalls/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_firewalls/optionsByFirewallType', firewallType.value)
      else
        return $store.dispatch('$_firewalls/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_firewalls/createFirewall', form.value),
    deleteItem: () => $store.dispatch('$_firewalls/deleteFirewall', id.value),
    getItem: () => $store.dispatch('$_firewalls/getFirewall', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_firewalls/updateFirewall', form.value),
  }
}

export default {
  useItemDefaults,
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
