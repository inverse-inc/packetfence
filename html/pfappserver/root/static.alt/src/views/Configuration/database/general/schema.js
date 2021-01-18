import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  host: yup.string().nullable().label(i18n.t('Host')),
  port: yup.string().nullable().label(i18n.t('Port')),
  db: yup.string().nullable().label(i18n.t('Database')),
  user: yup.string().nullable().label(i18n.t('User')),
  pass: yup.string().nullable().label(i18n.t('Password'))
})

export default schema

