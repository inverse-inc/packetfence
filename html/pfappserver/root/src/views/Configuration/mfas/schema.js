import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'mfaIdExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'mfaIdExistsExcept',
    message: message || i18n.t('Name already exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getMfas').then(response => {
        return response.filter(cloud => mfa.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .mfaIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name already exists.')),
    app_id: yup.string().nullable().label(i18n.t('Application ID')),
    app_secret: yup.string().nullable().label(i18n.t('Application Secret'))
  })
}

export default schema
