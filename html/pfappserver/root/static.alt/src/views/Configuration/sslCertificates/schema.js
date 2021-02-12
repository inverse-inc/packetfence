import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const schemaIntermediateCertificateAuthority = yup.string().nullable().required('Intermediate CA certificate required.')

const schemaIntermediateCertificateAuthorities = yup.array().of(schemaIntermediateCertificateAuthority)

export const schema = () => {
  return yup.object({
    lets_encrypt: yup.boolean(),
    common_name: yup.string()
      .when('lets_encrypt', {
        is: true,
        then: yup.string().nullable().required(i18n.t('Common name required.')),
        otherwise: yup.string().nullable(),
      }),
    certificate: yup.string()
      .when('lets_encrypt', {
        is: false,
        then: yup.string().nullable().required(i18n.t('Certificate required.')),
        otherwise: yup.string().nullable(),
      }),
    private_key: yup.string()
      .when('lets_encrypt', {
        is: false,
        then: yup.string().nullable().required(i18n.t('Private key required.')),
        otherwise: yup.string().nullable(),
      }),
    intermediate_cas: schemaIntermediateCertificateAuthorities.meta({ invalidFeedback: i18n.t('Intermediate CA certificates contain one or more errors.') })
  })
}

export default schema
