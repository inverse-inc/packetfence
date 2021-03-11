import i18n from '@/utils/locale'
import yup from '../yup'

export const schema = () => {
  return yup.object({
    device_class_whitelist: yup.string().nullable().label(i18n.t('Whitelist')),
    triggers: yup.string().nullable().label(i18n.t('Triggers'))
  })
}

export default schema
