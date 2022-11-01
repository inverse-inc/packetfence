import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  sso_authorize_path: yup.string().nullable().label(i18n.t('Path')),
  sso_base_url: yup.string().nullable().label(i18n.t('URL')),
  sso_login_path: yup.string().nullable().label(i18n.t('Path')),
  sso_login_text: yup.string().nullable().label(i18n.t('Text')),
})

export default schema

