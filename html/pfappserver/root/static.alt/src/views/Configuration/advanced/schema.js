import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  language: yup.string().nullable().label(i18n.t('Language')),
  hash_passwords: yup.string().nullable().label(i18n.t('Method')),
  hashing_cost: yup.string().nullable().label(i18n.t('Cost')),
  ldap_attributes: yup.string().nullable().label(i18n.t('Attributes')),
  pffilter_processes: yup.string().nullable().label(i18n.t('Processes')),
  pfperl_api_processes: yup.string().nullable().label(i18n.t('Processes')),
  pfperl_api_timeout: yup.string().nullable().label(i18n.t('Timeout')),
  timing_stats_level: yup.string().nullable().label(i18n.t('Level')),
  source_to_send_sms_when_creating_users: yup.string().nullable().label(i18n.t('Source')),
  netflow_on_all_networks: yup.string().nullable(),
  openid_attributes: yup.string().nullable().label(i18n.t('Attributes'))
})

export default schema

