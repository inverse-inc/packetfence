import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  password: yup.string().nullable().label(i18n.t('Key')),
  virtual_router_id: yup.string().nullable().label(i18n.t('Identifier')),
  api_connect_timeout: yup.string().nullable().label(i18n.t('Timeout')).minAsInt(1, i18n.t('Minimum 1 second.')),
  api_timeout: yup.string().nullable().label(i18n.t('Timeout')).minAsInt(1, i18n.t('Minimum 1 second.')),
  galera_replication_username: yup.string().nullable().label(i18n.t('Username')),
  galera_replication_password: yup.string().nullable().label(i18n.t('Password'))
})

export default schema

