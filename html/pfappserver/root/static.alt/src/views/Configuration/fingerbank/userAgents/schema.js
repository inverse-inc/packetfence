import i18n from '@/utils/locale'
import yup from '../yup'

export const schema = () => {
  return yup.object({
    value: yup.string().nullable().required(i18n.t('User Agent required.'))
  })
}

export default schema
