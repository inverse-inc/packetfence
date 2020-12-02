import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    device_id: yup.string().nullable().required(i18n.t('Device required.')),
    score: yup.string().nullable()
      .minAsInt(0, i18n.t('Minimum 0.'))
      .maxAsInt(100, i18n.t('Maximum 100.'))
  })
}

export default schema
