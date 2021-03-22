import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  wait_for_redirect: yup.string().nullable().label(i18n.t('Wait')),
  range: yup.string().nullable().label(i18n.t('Range')),
  passthroughs: yup.string().nullable().label(i18n.t('Domains')),
  proxy_passthroughs: yup.string().nullable().label(i18n.t('Domains')),
  isolation_passthroughs: yup.string().nullable().label(i18n.t('Domains')),
  interception_proxy_port: yup.string().nullable().label(i18n.t('Ports'))
})

export default schema

