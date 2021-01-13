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

const schemaAccessDurationChoices = yup.array().unique(i18n.t('Duplicate choice.')).of(schemaAccessDurationChoice)

export const schema = () => {
  return yup.object({
    access_duration_choices: schemaAccessDurationChoices
  })
}

export default schema
