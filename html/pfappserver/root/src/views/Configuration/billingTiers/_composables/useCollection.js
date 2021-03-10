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
        return i18n.t('Billing Tier: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Billing Tier: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Billing Tier')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'billing_tiers' }),
    goToItem: () => $router.push({ name: 'billing_tier', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneBillingTier', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_billing_tiers/isLoading']),
    getOptions: () => $store.dispatch('$_billing_tiers/options', id.value),
    createItem: () => $store.dispatch('$_billing_tiers/createBillingTier', form.value),
    deleteItem: () => $store.dispatch('$_billing_tiers/deleteBillingTier', id.value),
    getItem: () => $store.dispatch('$_billing_tiers/getBillingTier', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_billing_tiers/updateBillingTier', form.value)
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
