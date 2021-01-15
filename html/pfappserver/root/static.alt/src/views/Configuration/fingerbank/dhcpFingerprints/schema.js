import i18n from '@/utils/locale'
import yup from '../yup'

export const schema = () => {
  return yup.object({
    value: yup.string().nullable()
      .required(i18n.t('Fingerprint required.'))
      .isDHCPFingerprint(i18n.t('Invalid fingerprint.'))
  })
}

export default schema
