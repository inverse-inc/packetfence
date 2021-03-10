import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const schemaRoute = yup.string().nullable()
  .required(i18n.t('Static route required.'))
  .isStaticRoute()

const schemaRoutes = yup.array().ensure()
  .unique(i18n.t('Duplicate static route.'))
  .of(schemaRoute)

export const schema = () => yup.object({
  staticroutes: schemaRoutes,
  rogueinterval: yup.string().nullable().label(i18n.t('Interval')),
  interfaceSNAT: yup.string().nullable().label(i18n.t('Interface')),
})

export default schema
