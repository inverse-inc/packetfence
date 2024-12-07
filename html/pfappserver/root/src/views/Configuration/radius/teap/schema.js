import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'radiusTeapIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'radiusTeapIdNotExistsExcept',
    message: message || i18n.t('Identifier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getRadiusTeaps').then(response => {
        return response.filter(teap => teap.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .radiusTeapIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),
    authority_identity: yup.string().nullable().label(i18n.t('Authority Identity')),
    pac_opaque_key: yup.string().nullable().label(i18n.t('Key')),
    tls: yup.string().nullable().label(i18n.t('TLS Profile'))
  })
}
