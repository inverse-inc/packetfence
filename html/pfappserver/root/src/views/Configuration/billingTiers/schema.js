import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'billingTierIdentifierNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'billingTierIdentifierNotExistsExcept',
    message: message || i18n.t('Billing Tier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getBillingTiers').then(response => {
        return response.filter(billingTier => billingTier.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export default (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Billing Tier required.'))
      .billingTierIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Billing Tier exists.')),
    name: yup.string().nullable().label(i18n.t('Name'))
      .required(i18n.t('Name required.')),
    description: yup.string().nullable().label(i18n.t('Description'))
      .required(i18n.t('Description required.')),
    price: yup.string().nullable().label(i18n.t('Price'))
      .isPrice(i18n.t('Invalid price.'))
      .required(i18n.t('Price required.')),
    role: yup.string().nullable().label(i18n.t('Role'))
      .required(i18n.t('Role required.'))
  })
}
