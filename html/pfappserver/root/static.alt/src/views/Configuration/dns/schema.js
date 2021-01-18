import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  record_dns_in_sql: yup.string().nullable().label(i18n.t('Value'))
})

export default schema

