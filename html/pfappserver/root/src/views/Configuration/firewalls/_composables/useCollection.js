import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  firewallType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    firewallType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: firewallType.value }
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
        return i18n.t('Firewall SSO <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Firewall SSO <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Firewall SSO')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    firewallType
  } = toRefs(props)
  return computed(() => (firewallType.value || form.value.type))
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
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
