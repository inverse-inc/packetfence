import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  ports_redirect: yup.string().nullable().label(i18n.t('Ports')),
  interfaceSNAT: yup.string().nullable().label(i18n.t('Interfaces'))
})

export default schema

