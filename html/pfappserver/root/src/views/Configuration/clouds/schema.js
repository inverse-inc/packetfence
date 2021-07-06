import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'cloudIdExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'cloudIdExistsExcept',
    message: message || i18n.t('Name already exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getClouds').then(response => {
        return response.filter(cloud => cloud.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .required(i18n.t('Name required.'))
      .cloudIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name already exists.')),
    tenant_id: yup.string().nullable().label(i18n.t('Tenant ID')),
    client_id: yup.string().nullable().label(i18n.t('Client ID')),
    client_secret: yup.string().nullable().label(i18n.t('Client Secret'))
  })
}

export default schema
