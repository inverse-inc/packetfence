import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  status: yup.string().nullable().label(i18n.t('Enable')),
  cacert: yup.string().nullable().label(i18n.t('CA Certificate')),
  backend: yup.string().nullable().label(i18n.t('Backend host')),
})

export default schema

