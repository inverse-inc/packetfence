import apiCall from '@/utils/api'

export default {
  billingTiers: params => {
    return apiCall.get('config/billing_tiers', { params }).then(response => {
      return response.data
    })
  },
  billingTiersOptions: () => {
    return apiCall.options('config/billing_tiers').then(response => {
      return response.data
    })
  },
  billingTier: id => {
    return apiCall.get(['config', 'billing_tier', id]).then(response => {
      return response.data.item
    })
  },
  billingTierOptions: id => {
    return apiCall.options(['config', 'billing_tier', id]).then(response => {
      return response.data
    })
  },
  createBillingTier: data => {
    return apiCall.post('config/billing_tiers', data).then(response => {
      return response.data
    })
  },
  updateBillingTier: data => {
    return apiCall.patch(['config', 'billing_tier', data.id], data).then(response => {
      return response.data
    })
  },
  deleteBillingTier: id => {
    return apiCall.delete(['config', 'billing_tier', id])
  }
}
