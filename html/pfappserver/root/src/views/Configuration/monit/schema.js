import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    alert_email_to: yup.string().nullable().label(i18n.t('Alert Email To'))
      .isEmailCsv(),
  })
}

export default schema
