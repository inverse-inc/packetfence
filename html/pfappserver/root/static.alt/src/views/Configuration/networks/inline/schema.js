import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  layer3_accounting_session_timeout: yup.string().nullable().label(i18n.t('Timeout'))
    .minAsInt(1, i18n.t('Minimum {minValue}', { minValue: 1 })),
  layer3_accounting_sync_interval: yup.string().nullable().label(i18n.t('Interval'))
    .minAsInt(1, i18n.t('Minimum {minValue}', { minValue: 1 })),
  ports_redirect: yup.string().nullable().label(i18n.t('Ports')),
  interfaceSNAT: yup.string().nullable().label(i18n.t('Interfaces'))
})

export default schema

