import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    value: yup.string().nullable().required(i18n.t('DHCPv6 Enterprise required.'))
  })
}

export default schema
