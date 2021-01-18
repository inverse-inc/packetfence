import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const schemaAction = yup.string().nullable().label(i18n.t('Action'))

const schemaActions = yup.array().ensure().label(i18n.t('Actions')).of(schemaAction)

export const schema = () => yup.object({
  trap_limit_threshold: yup.string().nullable().label(i18n.t('Limit')),
  trap_limit_action: schemaActions
})

export default schema
