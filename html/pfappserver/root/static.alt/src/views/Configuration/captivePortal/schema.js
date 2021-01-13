import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  ip_address: yup.string().nullable().label('IP'),
  image_path: yup.string().nullable().label(i18n.t('Path')),
  request_timeout: yup.string().nullable().label(i18n.t('Timeout')),
  loadbalancers_ip: yup.string().nullable().label('IP'),
  detection_mecanism_urls: yup.string().nullable().label('URL'),
  rate_limiting_threshold: yup.string().nullable().label(i18n.t('Threshold')),
  other_domain_names: yup.string().nullable().label(i18n.t('Domains'))
})

export default schema

