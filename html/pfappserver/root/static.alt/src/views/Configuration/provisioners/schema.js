import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'provisionerIdExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'provisionerIdExistsExcept',
    message: message || i18n.t('Provisioning ID exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getProvisionings').then(response => {
        return response.filter(provisioning => provisioning.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export const schema = (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Provisioning ID required.'))
      .provisionerIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Provisioning ID exists.')),
    api_username: yup.string().nullable().label(i18n.t('API username')),
    api_password: yup.string().nullable().label(i18n.t('API password')),
    tenant_code: yup.string().nullable().label(i18n.t('Tenant code')),
    ssid: yup.string().nullable().label(i18n.t('SSID'))
  })
}

export default schema
