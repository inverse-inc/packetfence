import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    domain: yup.string().nullable().label(i18n.t('Domain')),
    hostname: yup.string().nullable().label(i18n.t('Hostname')),
    dhcpservers: yup.string().nullable().label(i18n.t('Servers')),
    timezone: yup.string().nullable().label(i18n.t('Timezone'))
  })
}

export default schema
