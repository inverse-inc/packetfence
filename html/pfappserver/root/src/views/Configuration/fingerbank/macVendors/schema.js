import i18n from '@/utils/locale'
import yup from '../yup'

export const schema = () => {
  return yup.object({
    name: yup.string().nullable().required(i18n.t('Vendor required.')),
    mac: yup.string().nullable()
      .required(i18n.t('OUI required.'))
      .isOUI(i18n.t('Invalid OUI.'))
  })
}

export default schema
