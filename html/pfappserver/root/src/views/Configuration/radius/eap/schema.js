import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'radiusEapIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'radiusEapIdNotExistsExcept',
    message: message || i18n.t('Identifier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getRadiusEaps').then(response => {
        return response.filter(eap => eap.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .radiusEapIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),
    cisco_accounting_username_bug: yup.string().nullable().label(i18n.t('Username Bug')),
    default_eap_type: yup.string().nullable().label(i18n.t('EAP Type')),
    eap_authentication_types: yup.array().ensure().of(yup.string().nullable().label(i18n.t('EAP Authentication Types'))),
    fast_config: yup.string().nullable().label(i18n.t('Fast Profile')),
    teap_config: yup.string().nullable().label(i18n.t('TEAP Profile')),
    ignore_unknown_eap_types: yup.string().nullable().label(i18n.t('Ignore Unknown')),
    max_sessions: yup.string().nullable().label(i18n.t('Max Sessions')),
    peap_tlsprofile: yup.string().nullable().label(i18n.t('PEAP Profile')),
    timer_expire: yup.string().nullable().label(i18n.t('Expires')),
    tls_tlsprofile: yup.string().nullable().label(i18n.t('TLS Profile')),
    ttls_tlsprofile: yup.string().nullable().label(i18n.t('TTLS Profile'))
  })
}
