import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => yup.object({
  key_buffer_size: yup.string().nullable().label(i18n.t('Size')),
  innodb_buffer_pool_size: yup.string().nullable().label(i18n.t('Size')),
  innodb_additional_mem_pool_size: yup.string().nullable().label(i18n.t('Size')),
  query_cache_size: yup.string().nullable().label(i18n.t('Size')),
  thread_concurrency: yup.string().nullable().label(i18n.t('Concurrency')),
  max_connections: yup.string().nullable().label(i18n.t('Connections')),
  table_cache: yup.string().nullable().label(i18n.t('Cache')),
  thread_cache_size: yup.string().nullable().label(i18n.t('Size')),
  max_allowed_packet: yup.string().nullable().label(i18n.t('Packets')),
  performance_schema: yup.string().nullable().label(i18n.t('Schema')),
  max_connect_errors: yup.string().nullable().label(i18n.t('Errors')),
  masterslave: yup.string().nullable().label(i18n.t('Mode')),
  other_members: yup.string().nullable().label('Other MySQL Servers')
})

export default schema

