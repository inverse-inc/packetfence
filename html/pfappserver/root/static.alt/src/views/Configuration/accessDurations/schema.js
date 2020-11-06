import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const schemaAccessDurationChoice = yup.object({
  interval: yup.string()
    .nullable()
    .required(i18n.t('Interval required.')),

  unit: yup.string()
    .nullable()
    .required(i18n.t('Unit required.')),

  base: yup.string().nullable(),

  extendedInterval: yup.string()
    .nullable()
    .when('base', {
      is: value => !value,
      then: yup.string().nullable(),
      otherwise: yup.string().nullable().required(i18n.t('Interval required.')),
    }),

  extendedUnit: yup.string()
    .nullable()
    .when('base', {
      is: value => !value,
      then: yup.string().nullable(),
      otherwise: yup.string().nullable().required(i18n.t('Unit required.')),
    })
})

const schemaAccessDurationChoices = yup.array().of(schemaAccessDurationChoice)

export const schema = (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object({
    access_duration_choices: schemaAccessDurationChoices.meta({ invalidFeedback: i18n.t('Choices contain one or more errors.') })
  })
}

export default schema
