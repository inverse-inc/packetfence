import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  lease_length: yup.string().nullable().label(i18n.t('Length')),
  threshold: yup.string().nullable().label(i18n.t('Threshold'))
})

export default schema

