import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    name: yup.string().nullable().required(i18n.t('Vendor required.')),
    mac: yup.string().nullable().required(i18n.t('OUI required.'))
      .matches(/^[0-9a-fA-F]{6}$/, i18n.t('Invalid OUI.'))
  })
}

export default schema
