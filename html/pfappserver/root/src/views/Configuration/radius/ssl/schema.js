import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'radiusSslIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'radiusSslIdNotExistsExcept',
    message: message || i18n.t('Identifier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getRadiusSsls').then(response => {
        return response.filter(ssl => ssl.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .required(i18n.t('Identifier required.'))
      .radiusSslIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),
    ca: yup.string().nullable().label(i18n.t('Certificate Authority')),
    cert: yup.string().nullable().label(i18n.t('Certificate')),
    intermediate: yup.string().nullable().label(i18n.t('Intermediate')),
    key: yup.string().nullable().label(i18n.t('Private Key')),
    private_key_password: yup.string().nullable().label(i18n.t('Private Key Password'))
  })
}
