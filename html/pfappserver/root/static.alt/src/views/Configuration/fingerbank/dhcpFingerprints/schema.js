import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    value: yup.string().nullable().required(i18n.t('DHCP Fingerprint required.'))
  })
}

export default schema
