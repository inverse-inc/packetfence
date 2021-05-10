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
        return i18n.t('Billing Tier <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Billing Tier <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Billing Tier')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
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
