import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'tenantNameNotExistsExceptIdentifier', function (exceptId = '', message) {
  return this.test({
    name: 'tenantNameNotExistsExceptIdentifier',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value) return true
      return store.dispatch('config/getTenants').then(response => {
        return response.filter(tenant =>
          tenant.name.toLowerCase() === value.toLowerCase()
          && tenant.id.toString() !== exceptId.toString()
        ).length === 0
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
      .required(i18n.t('Identifier required.')),
    name: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .tenantNameNotExistsExceptIdentifier((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    domain_name: yup.string().nullable(),
    portal_domain_name: yup.string().nullable()
  })
}

export { yup }
