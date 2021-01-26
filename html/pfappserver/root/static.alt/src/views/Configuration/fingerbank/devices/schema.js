import i18n from '@/utils/locale'
import yup from '../yup'

export const schema = () => {
  return yup.object({
    name: yup.string().nullable().required(i18n.t('Name required.'))
  })
}

export default schema
