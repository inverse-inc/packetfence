import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'radiusTlsIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'radiusTlsIdNotExistsExcept',
    message: message || i18n.t('Identifier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getRadiusTlss').then(response => {
        return response.filter(tls => tls.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .radiusTlsIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),
    ca_path: yup.string().nullable().label(i18n.t('CA Path')),
    certificate_profile: yup.string().nullable().label(i18n.t('Certificate Profile')),
    cipher_list: yup.string().nullable().label(i18n.t('Cipher List')),
    dh_file: yup.string().nullable().label(i18n.t('DH File')),
    ecdh_curve: yup.string().nullable().label(i18n.t('ECDH Curve')),
    ocsp: yup.string().nullable().label(i18n.t('OCSP Profile'))
  })
}
