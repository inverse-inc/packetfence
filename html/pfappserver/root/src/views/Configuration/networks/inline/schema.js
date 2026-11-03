import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  ports_redirect: yup.string().nullable().label(i18n.t('Ports')).isPortProtocolCsv(),
  interfaceSNAT: yup.string().nullable().label(i18n.t('Interfaces')).isInterfaceNameCsv()
})

export default schema

