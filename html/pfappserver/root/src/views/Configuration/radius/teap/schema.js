import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'radiusTeapIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'radiusTeapIdNotExistsExcept', message: message || i18n.t('Identifier exists.'), test: (value) => {
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
    id, isNew, isClone
  } = props

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifier required.'))
      .max(20)
      .isAlphaNumericHyphenUnderscoreDot()
      .radiusTeapIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),
    authority_identity: yup.string().nullable().label(i18n.t('Authority Identity')),
    identity_types: yup.string().nullable().label(i18n.t('Identity Types')),
    tls: yup.string().nullable().label(i18n.t('TLS Profile')),
    default_eap_type: yup.string().nullable().label(i18n.t('Default EAP Type')),
    user_eap_type: yup.string().nullable().label(i18n.t('User EAP Type')),
    machine_eap_type: yup.string().nullable().label(i18n.t('Machine EAP Type'))
  })
}
