import i18n from '@/utils/locale'
import yup from '../yup'

export const schema = () => {
  return yup.object({
    upstream: yup.object({
      api_key: yup.string().nullable().label(i18n.t('Key')),
      host: yup.string().nullable().label(i18n.t('Host')),
      port: yup.string().nullable().label(i18n.t('Port')),
      db_path: yup.string().nullable().label(i18n.t('Path')),
      sqlite_db_retention: yup.string().nullable().label(i18n.t('Amount'))
    }),
    collector: yup.object({
      host: yup.string().nullable().label(i18n.t('Host')),
      port: yup.string().nullable().label(i18n.t('Port')),
      inactive_endpoints_expiration: yup.string().nullable().label(i18n.t('Hours')),
      query_cache_time: yup.string().nullable().label(i18n.t('Time')),
      db_persistence_interval: yup.string().nullable().label(i18n.t('Interval')),
      cluster_resync_interval: yup.string().nullable().label(i18n.t('Interval'))
    }),
    proxy: yup.object({
      host: yup.string().nullable().label(i18n.t('Host')),
      port: yup.string().nullable().label(i18n.t('Port'))
    })
  })
}

export default schema

