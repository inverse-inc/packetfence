import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  eap_authentication_types: yup.string().nullable().label(i18n.t('Types')),
  eap_fast_opaque_key: yup.string().nullable().label(i18n.t('Key')),
  eap_fast_authority_identity: yup.string().nullable().label(i18n.t('Identity')),
  radius_attributes: yup.string().nullable().label(i18n.t('Attributes')),
  username_attributes: yup.string().nullable().label(i18n.t('Attributes')),
  ocsp_url: yup.string().nullable().label(i18n.t('URL')),
  ocsp_timeout: yup.string().nullable().label(i18n.t('Timeout'))
})

export default schema

